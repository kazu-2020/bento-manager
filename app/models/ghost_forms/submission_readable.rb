# frozen_string_literal: true

module GhostForms
  # 「送信されたのに中身が残らなかった」を、どのフォームでも同じ判定・同じエラーで差し戻す。
  # なぜ空判定を素のハッシュでやってはいけないかは GhostForms::Submission を参照。
  #
  # フォームはメインフォームと Ghost Form の両方のコントローラーから使われる
  # （ghost-form-pattern ルール 3）。判定をコントローラーに置くと、同じフォームを
  # 組み立てる別のコントローラーが素通しになる。差し戻しの結果は利用者に見せる
  # エラーでもあるので、フォームに持たせる。
  module SubmissionReadable
    extend ActiveSupport::Concern

    included do
      validate :submitted_readable
    end

    private

    # フォームは initialize で @submitted に GhostForms::Submission を必ず代入する。
    # Ghost Form の描画経路は valid? を呼ばないため、代入漏れは黙って生き延びうる。
    # nil のまま進ませず、何を忘れたかが分かる形で落とす
    def submitted
      @submitted || raise("#{self.class} は #initialize で @submitted に GhostForms::Submission を代入すること")
    end

    # 送信されたなら必ず中身があるはずの最上位キー。既定は最上位全体を見る。
    # 一部のキーだけが必須のフォームがこれを上書きする（例: Refunds::RefundForm）
    def required_submitted_keys
      []
    end

    # 送信されたのに必要な中身が残らなかったか。判定しようのない他のバリデーションを
    # 黙らせる（重ねて出すと本当の理由が埋もれる）ためにフォームからも参照する
    def submitted_unreadable?
      submitted.unreadable?(required_submitted_keys)
    end

    def submitted_readable
      errors.add(:base, :unreadable_submission) if submitted_unreadable?
    end
  end
end
