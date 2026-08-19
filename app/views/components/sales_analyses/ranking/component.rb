# frozen_string_literal: true

module SalesAnalyses
  module Ranking
    class Component < Application::Component
      # 顧客タイプごとの配色。Tailwind はソースを静的解析するため、クラス名は完全なリテラルで持つ。
      # 並び順がそのままカードの並び順になる
      CUSTOMER_TYPE_STYLES = {
        staff: { icon_wrapper: "rounded-lg bg-staff/10 p-2", icon: "text-staff" },
        citizen: { icon_wrapper: "rounded-lg bg-citizen/10 p-2", icon: "text-citizen" }
      }.freeze

      def initialize(data:)
        @data = data
      end

      private

      attr_reader :data

      def customer_types
        CUSTOMER_TYPE_STYLES.keys
      end

      # 顧客タイプの呼称は enum ラベルが正典なので、表題はそれを差し込んで組み立てる
      def title_for(customer_type)
        t(".title", customer_type: t("enums.sale.customer_type.#{customer_type}"))
      end

      def icon_wrapper_class(customer_type)
        CUSTOMER_TYPE_STYLES.dig(customer_type, :icon_wrapper)
      end

      def icon_class(customer_type)
        CUSTOMER_TYPE_STYLES.dig(customer_type, :icon)
      end
    end
  end
end
