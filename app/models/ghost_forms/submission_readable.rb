# frozen_string_literal: true

module GhostForms
  # 「送信されたのに中身が残らなかった」を、どのフォームでも同じ判定・同じエラーで差し戻す。
  #
  # フォームはメインフォームと Ghost Form の両方のコントローラーから使われる
  # （ghost-form-pattern ルール 3）。判定をコントローラーに置くと、同じフォームを
  # 組み立てる別のコントローラーが素通しになる。差し戻しの結果は利用者に見せる
  # エラーでもあるので、フォームに持たせる。
  #
  # include したフォームは initialize で @submitted に GhostForms::Submission を
  # 必ず代入すること（代入し忘れると valid? で NoMethodError になり、黙って
  # 素通しにはならない）。
  module SubmissionReadable
    extend ActiveSupport::Concern

    included do
      # 宣言しなければ最上位全体を見る
      class_attribute :required_submitted_keys, instance_writer: false, default: [].freeze

      attr_reader :submitted

      validate :submitted_readable
    end

    class_methods do
      # 送信されたなら必ず中身があるはずの最上位キー。
      # 例: 返品は corrected（修正後の数量）が空なら「全て 0」ではなく壊れた送信
      def requires_submitted(*keys)
        self.required_submitted_keys = keys.map(&:to_s).freeze
      end
    end

    private

    def submitted_readable
      errors.add(:base, :unreadable_submission) if submitted.unreadable?(required_submitted_keys)
    end
  end
end
