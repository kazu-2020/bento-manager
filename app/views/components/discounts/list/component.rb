# frozen_string_literal: true

module Discounts
  module List
    class Component < Application::Component
      def initialize(discounts:)
        # ロードまで済ませて受け取る。relation のままだと、下の empty? が未ロードに当たって
        # 存在確認だけの問い合わせを 1 本撃つ。そのあとカードの描画で本体を読み直すので、
        # 同じ SQL に畳まれることもない（母集合の作り方は Discount.with_discountable）
        @discounts = discounts.to_a
      end

      attr_reader :discounts

      def empty?
        discounts.empty?
      end
    end
  end
end
