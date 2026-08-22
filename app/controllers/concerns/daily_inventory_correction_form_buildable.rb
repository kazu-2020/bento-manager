# frozen_string_literal: true

module DailyInventoryCorrectionFormBuildable
  extend ActiveSupport::Concern
  include SubmittedParamsFilterable

  included do
    before_action :set_location
  end

  private

  def set_location
    @location = Location.active.find(params[:location_id])
  end

  # 確定用と Ghost Form の 2 つの入口が同じフォームを組み立てる（ghost-form-pattern.md
  # ルール 3）。母集合がずれると、送信されなかった商品が「0 に減った」と読まれて
  # bulk_recreate が既存在庫を破壊的に作り直す。
  # search_query は表示の絞り込みにしか効かない（ItemSelectable#visible?）が、確定側でも
  # 読むのはバリデーション差し戻しの再描画で検索語を保つため
  def build_form(submitted = ::GhostForms::Submission.absent)
    ::DailyInventories::CorrectionForm.new(
      location: @location,
      catalogs: Catalog.available_or_stocked_at(@location).category_order,
      search_query: params[:search_query],
      submitted: submitted
    )
  end
end
