module Backups
  # 復元したコピーが「事故ったときに実際に戻せるもの」かを判定する（ADR-0001 決定 6）
  #
  # integrity_check だけでは足りない。レプリケーションが 3 週間前に止まっていても、
  # 「3 週間前の完全に健全な DB」が復元されて緑を返し続けるため。
  #
  # 逆に「復元した DB の最新の売上が十分新しいこと」を条件にしてはならない。
  # 出張販売は毎日あるとは限らず、休業日には必ず誤検知する。業務データの新しさを
  # 健全性の指標に使うと、業務のリズムがそのまま監視のノイズになる。
  class ReplicaVerification
    SALES_STATE_SQL = "SELECT COALESCE(MAX(id), 0), COUNT(*) FROM sales".freeze

    def initialize(restored_path:, tolerance:)
      @restored_path = restored_path
      @tolerance = tolerance
    end

    def call
      restored = SQLite3::Database.new(@restored_path.to_s, readonly: true)

      integrity = integrity_check(restored)
      return DrillResult.failure("PRAGMA integrity_check が通らなかった: #{integrity}") unless integrity == "ok"

      begin
        restored_max_id, restored_count = restored.get_first_row(SALES_STATE_SQL)
      rescue SQLite3::Exception => e
        # integrity_check を通ったのに sales が読めないのは、健全な「別の」データベースを
        # 復元したということ。壊れている場合と原因が違うので、混ぜて報告しない。
        return DrillResult.failure("復元したコピーから sales を読み出せなかった: #{e.message}")
      end

      # 本番は復元「後」に読む。順序を逆にすると、復元中に入った売上が
      # 「復元側の遅れ」として現れ、営業時間中の訓練が理由なく赤くなる。
      # 最大 id と件数は 1 クエリで取る。2 回に分けると、その間に売上が入ったとき
      # 別時点の値どうしを比べることになり、許容差の判定が意味を失う。
      production_max_id, production_count = Sale.pick(Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COUNT(*)"))

      compare("最大 id", restored_max_id, production_max_id) ||
        compare("件数", restored_count, production_count) ||
        DrillResult.success(
          "復元したコピーは本番に追いついている" \
          "（最大 id #{restored_max_id}/#{production_max_id}、件数 #{restored_count}/#{production_count}）"
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

    def compare(label, restored_value, production_value)
      if restored_value > production_value
        return DrillResult.failure(
          "復元したコピーの sales の#{label}が本番より進んでいる" \
          "（復元 #{restored_value} / 本番 #{production_value}）。別のデータベースを復元している可能性がある"
        )
      end

      lag = production_value - restored_value
      return nil if lag <= @tolerance

      DrillResult.failure(
        "復元したコピーの sales の#{label}が本番より #{lag} 遅れている（許容差 #{@tolerance}）。" \
        "レプリケーションが止まっている可能性がある"
      )
    end
  end
end
