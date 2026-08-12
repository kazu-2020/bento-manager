# frozen_string_literal: true

# Ghost Form のパラメータを、フォームが宣言した形状で検証して取り出す。
# 検証の中身は GhostForms::ParamsFilter を参照。
module SubmittedParamsFilterable
  extend ActiveSupport::Concern

  private

  def submitted_params(key, form:)
    ::GhostForms::ParamsFilter.call(params[key], **form::SUBMITTED_PARAMS_SHAPE)
  end
end
