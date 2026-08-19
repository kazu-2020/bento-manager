# frozen_string_literal: true

require "test_helper"

module Sales
  class AnalysisPeriodTest < ActiveSupport::TestCase
    # パラメータは丸めて受け入れるが、集計期間そのものは対応する集計日数でしか作れない
    test "対応していない集計日数は既定の30日として扱われる" do
      assert_equal 7, AnalysisPeriod.from_param("7").days
      [ 999, nil, "", 0, -7, 6, 8, 29, 31, 89, 91, [ "7" ], { "a" => "7" } ].each do |days|
        assert_equal 30, AnalysisPeriod.from_param(days).days, "#{days.inspect} は 30 に丸められる"
      end

      assert_raises(ArgumentError) { AnalysisPeriod.new(days: 31) }
    end

    test "集計期間は当日を含まず、前日を終端とする直近 N 暦日を指す" do
      AnalysisPeriod::ALLOWED_DAYS.each do |days|
        period = AnalysisPeriod.from_param(days)

        assert_equal Date.current - days, period.first_date
        assert_equal Date.current - 1, period.last_date
        assert_equal (Date.current - days).in_time_zone.beginning_of_day, period.from
        assert_equal (Date.current - 1).in_time_zone.end_of_day, period.to
      end
    end
  end
end
