module Backups
  # 復元したコピーが「事故ったときに実際に戻せるもの」かを判定する（ADR-0001 決定 6）
  #
  # 判定は 2 段構え。
  #
  #   1. PRAGMA integrity_check — 復元物がデータベースとして壊れていないこと
  #   2. 本番との一致            — 復元物が本番の今の状態に追いついていること
  #
  # 1 だけでは足りない。レプリケーションが 3 週間前に止まっていても、
  # 「3 週間前の完全に健全な DB」が復元されて緑を返し続けるため。
  #
  # 逆に「復元した DB の最新の売上が十分新しいこと」を条件にしてはならない。
  # 出張販売は毎日あるとは限らず、休業日には必ず誤検知する。業務データの新しさを
  # 健全性の指標に使うと、業務のリズムがそのまま監視のノイズになる。
  #
  # 「本番と一致しているか」は業務のリズムに影響されない。休業日は本番も止まるので
  # 一致し、営業日にレプリケーションが止まれば即座に不一致になる。
  class ReplicaVerification
    SALES_STATE_SQL = "SELECT COALESCE(MAX(id), 0), COUNT(*) FROM sales".freeze

    # @param restored_path [String, Pathname] 復元したコピーのパス
    # @param tolerance [Integer] 復元側が本番より遅れていることを許容する幅
    def initialize(restored_path:, tolerance:)
      @restored_path = restored_path
      @tolerance = tolerance
    end

    # @return [DrillResult]
    def call
      restored = SQLite3::Database.new(@restored_path.to_s, readonly: true)

      integrity = restored.get_first_value("PRAGMA integrity_check")
      return failure("PRAGMA integrity_check が通らなかった: #{integrity}") unless integrity == "ok"

      restored_max_id, restored_count = restored.get_first_row(SALES_STATE_SQL)

      # 本番は復元「後」に読む。順序を逆にすると、復元中に入った売上が
      # 「復元側の遅れ」として現れ、営業時間中の訓練が理由なく赤くなる。
      production_max_id = Sale.maximum(:id) || 0
      production_count = Sale.count

      compare(
        [ "最大 id", restored_max_id, production_max_id ],
        [ "件数", restored_count, production_count ]
      )
    rescue SQLite3::Exception => e
      failure("PRAGMA integrity_check を実行できなかった: #{e.message}")
    ensure
      restored&.close
    end

    private

    def compare(*axes)
      axes.each do |label, restored_value, production_value|
        if restored_value > production_value
          return failure(
            "復元したコピーの sales の#{label}が本番より進んでいる" \
            "（復元 #{restored_value} / 本番 #{production_value}）。別のデータベースを復元している可能性がある"
          )
        end

        lag = production_value - restored_value
        next if lag <= @tolerance

        return failure(
          "復元したコピーの sales の#{label}が本番より #{lag} 遅れている（許容差 #{@tolerance}）。" \
          "レプリケーションが止まっている可能性がある"
        )
      end

      DrillResult.success(
        "復元したコピーは本番に追いついている（#{axes.map { |label, r, p| "#{label} #{r}/#{p}" }.join('、')}）"
      )
    end

    def failure(message) = DrillResult.failure(message)
  end
end
