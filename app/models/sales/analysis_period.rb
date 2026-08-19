# frozen_string_literal: true

module Sales
  # 売上分析が対象とする集計期間。当日を除いた、確定済みの直近 N 暦日を指す。
  # 当日の販売は差額精算で変わりうるため、混ぜると同じ期間の数字が見るたびに動く。
  class AnalysisPeriod
    # 受け付ける集計日数の集合。UI のプリセットはこの集合をそのまま並べたもので、
    # 入力の集合が主・プリセットは従という関係にある
    ALLOWED_DAYS = [ 7, 30, 90 ].freeze
    DEFAULT_DAYS = 30

    # URL パラメータの集計日数を正規化して集計期間を組み立てる。
    # days[]=7 のように配列やハッシュで届くこともあるため、to_s を挟んで 0 に倒す
    def self.from_param(days)
      days = days.to_s.to_i
      new(days: ALLOWED_DAYS.include?(days) ? days : DEFAULT_DAYS)
    end

    # @return [Integer] 集計日数
    attr_reader :days

    # @return [Date] 集計期間の最終日（前日）
    attr_reader :last_date

    def initialize(days:)
      raise ArgumentError, "対応していない集計日数: #{days.inspect}" unless ALLOWED_DAYS.include?(days)

      @days = days
      # 両端が暦日なので、集計期間の基準は Time.current ではなく Date.current に固定する
      @last_date = Date.current - 1
    end

    # 集計期間の初日
    # @return [Date]
    def first_date
      last_date - (days - 1)
    end

    # 暦日をどの瞬間として扱うかは集計期間が決め、Sale.in_period にはその Time を渡す
    def from
      first_date.in_time_zone.beginning_of_day
    end

    def to
      last_date.in_time_zone.end_of_day
    end
  end
end
