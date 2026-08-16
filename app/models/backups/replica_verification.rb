module Backups
  # 復元したコピーが「事故ったときに実際に戻せるもの」かを判定する（ADR-0001 決定 6）
  #
  # integrity_check だけでは足りない。レプリケーションが 3 週間前に止まっていても、
  # 「3 週間前の完全に健全な DB」が復元されて緑を返し続けるため。
  #
  # 逆に「復元した DB の最新の売上が十分新しいこと」を条件にしてはならない。
  # 出張販売は毎日あるとは限らず、休業日には必ず誤検知する。業務データの新しさを
  # 健全性の指標に使うと、業務のリズムがそのまま監視のノイズになる。
  #
  # ただし売上だけを突き合わせると、売上が動かない日は両者が自明に一致し、
  # 判定が integrity_check だけに退化する。そこを塞ぐのが Heartbeat で、
  # 訓練が毎回書くため業務のリズムに影響されない。
  class ReplicaVerification
    SALES_STATE_SQL = "SELECT COALESCE(MAX(id), 0), COUNT(*) FROM #{Sale.table_name}".freeze
    MAX_HEARTBEAT_ID_SQL = "SELECT COALESCE(MAX(id), 0) FROM #{Heartbeat.table_name}".freeze

    SALES_STATE_COLUMNS = [ Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COUNT(*)") ].freeze

    # @param required_heartbeat_id [Integer] 復元側に入っているべきハートビートの id。
    #   訓練が「今回」書いた分を渡す。前回の分で妥協すると、1 日分の猶予が
    #   そのまま検知の遅れになる（RestoreDrill::PROPAGATION_WAIT_SECONDS 参照）。
    def initialize(restored_path:, tolerance:, required_heartbeat_id:)
      @restored_path = restored_path
      @tolerance = tolerance
      @required_heartbeat_id = required_heartbeat_id
    end

    def call
      begin
        restored = SQLite3::Database.new(@restored_path.to_s, readonly: true)
      rescue SQLite3::Exception => e
        # litestream が終了コード 0 のまま出力を作らなかった場合がここに来る。
        # 開けないことも「戻せない」という検証結果なので、例外で抜けずに失敗として返す。
        return DrillResult.failure("復元したコピーを開けなかった: #{e.message}")
      end

      integrity = integrity_check(restored)
      return DrillResult.failure("PRAGMA integrity_check が通らなかった: #{integrity}") unless integrity == "ok"

      begin
        restored_max_id, restored_count = restored.get_first_row(SALES_STATE_SQL)
        restored_heartbeat_id = restored.get_first_value(MAX_HEARTBEAT_ID_SQL)
      rescue SQLite3::Exception => e
        # integrity_check を通ったのにテーブルが読めないのは、健全な「別の」データベースを
        # 復元したということ。壊れている場合と原因が違うので、混ぜて報告しない。
        return DrillResult.failure("復元したコピーからテーブルを読み出せなかった: #{e.message}")
      end

      # 本番は復元「後」に読む。先に読むと、リストア中に入った売上のぶん復元側が本番より
      # 「進んで」見え、別のデータベースを復元した疑いとして誤検知する。後に読めば同じズレは
      # 遅れとして現れ、許容差で吸収できる。
      # 最大 id と件数は 1 クエリで取る。2 回に分けると、その間に売上が入ったとき
      # 別時点の値どうしを比べることになり、許容差の判定が意味を失う。
      production_max_id, production_count = Sale.pick(*SALES_STATE_COLUMNS)
      production_heartbeat_id = Heartbeat.maximum(:id) || 0

      compare("売上の最大 id", restored_max_id, production_max_id) ||
        compare("売上の件数", restored_count, production_count) ||
        check_heartbeat(restored_heartbeat_id, production_heartbeat_id) ||
        DrillResult.success(
          "復元したコピーは本番に追いついている" \
          "（売上 #{restored_count}/#{production_count} 件、ハートビート id #{restored_heartbeat_id}）"
        )
    ensure
      restored&.close
    end

    private

    # 復元物が壊れていると PRAGMA そのものが例外になる
    def integrity_check(restored)
      restored.get_first_value("PRAGMA integrity_check")
    rescue SQLite3::Exception => e
      "復元物を読めなかった（#{e.message}）"
    end

    # 今回書いたハートビートが復元側に無ければ、複製は今この瞬間止まっている。
    # 売上と違い訓練は毎日走るので、この条件は店の営業日に左右されない。
    def check_heartbeat(restored_heartbeat_id, production_heartbeat_id)
      ahead_of_production("ハートビートの id", restored_heartbeat_id, production_heartbeat_id) ||
        missing_heartbeat(restored_heartbeat_id)
    end

    def missing_heartbeat(restored_heartbeat_id)
      return nil if restored_heartbeat_id >= @required_heartbeat_id

      DrillResult.failure(
        "今回の訓練のハートビート（id #{@required_heartbeat_id}）が復元したコピーに無い" \
        "（復元側の最新は id #{restored_heartbeat_id}）。レプリケーションが止まっている"
      )
    end

    # 本番に存在しない値が復元側にあるのは、遅れではなく別物を復元したということ。
    # 売上とハートビートで判定が食い違わないよう、どちらもこれを先に通す。
    def ahead_of_production(label, restored_value, production_value)
      return nil unless restored_value > production_value

      DrillResult.failure(
        "復元したコピーの#{label}が本番より進んでいる" \
        "（復元 #{restored_value} / 本番 #{production_value}）。別のデータベースを復元している可能性がある"
      )
    end

    def compare(label, restored_value, production_value)
      ahead = ahead_of_production(label, restored_value, production_value)
      return ahead if ahead

      lag = production_value - restored_value
      return nil if lag <= @tolerance

      DrillResult.failure(
        "復元したコピーの#{label}が本番より #{lag} 遅れている（許容差 #{@tolerance}）。" \
        "レプリケーションが止まっている可能性がある"
      )
    end
  end
end
