# frozen_string_literal: true

module DailyInventoryFormBuildable
  extend ActiveSupport::Concern
  include SubmittedParamsFilterable
  include SearchQueryFilterable

  included do
    before_action :set_location
  end

  private

  def set_location
    @location = Location.active.find(params[:location_id])
  end

  # 確定用と Ghost Form の 2 つの入口が同じフォームを組み立てる（ghost-form-pattern.md
  # ルール 3）。search_query は表示の絞り込みにしか効かない（ItemSelectable#visible?）が、
  # 確定側でも読むのはバリデーション差し戻しの再描画で検索語を保つため
  def build_form(submitted = ::GhostForms::Submission.absent)
    ::DailyInventories::InventoryForm.new(
      location: @location,
      catalogs: Catalog.available.category_order,
      search_query: search_query_param,
      submitted: submitted
    )
  end
end
