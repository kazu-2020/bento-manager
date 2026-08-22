# frozen_string_literal: true

module SalesHistories
  module DailyDetailPanel
    class Component < Application::Component
      # 販売数は弁当だけを数え、取引件数は全商品の取引を数える。同じ日を 2 つの
      # 母集合で見せるのは、集計は弁当の売れ方を、件数はその日の商いを表すため（ADR-0006）
      def initialize(date:, location:, breakdown:, transaction_count:)
        @date = date
        @location = location
        @breakdown = breakdown
        @transaction_count = transaction_count
      end

      private

      attr_reader :date, :location, :breakdown, :transaction_count

      def total_quantity
        breakdown.sum { |row| row[:total_quantity] }
      end

      def show_path
        helpers.sales_history_path(date.to_s, location_id: location.id)
      end

      def max_quantity
        @max_quantity ||= breakdown.map { |r| r[:total_quantity] }.max || 1
      end

      # 行全体のバー幅（最大行を100%とした相対幅）
      def bar_total_width(row)
        "#{(row[:total_quantity] * 100.0 / max_quantity).round}%"
      end

      # バー内の staff 部分の割合
      def staff_ratio(row)
        return "0%" if row[:total_quantity].zero?
        "#{(row[:staff_quantity] * 100.0 / row[:total_quantity]).round}%"
      end
    end
  end
end
