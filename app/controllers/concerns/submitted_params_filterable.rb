# frozen_string_literal: true

# Ghost Form のパラメータを、フォームが宣言した形状で検証して取り出す。
# 「未送信」と「送信されたが読めなかった」を区別できる GhostForms::Submission を返し、
# 素のハッシュは返さない。区別の理由は GhostForms::Submission を参照。
module SubmittedParamsFilterable
  extend ActiveSupport::Concern

  private

  def submitted_params(key, form:)
    ::GhostForms::Submission.filter(params[key], form: form)
  end
end
