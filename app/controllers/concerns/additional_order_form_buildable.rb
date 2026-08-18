# frozen_string_literal: true

module AdditionalOrderFormBuildable
  extend ActiveSupport::Concern
  include SubmittedParamsFilterable

  private

  def set_location
    @location = Location.active.find(params[:location_id])
  end

  def build_form(submitted = ::GhostForms::Submission.absent)
    catalogs = Catalog.bento.available.order(:kana)
    stock_map = @location.today_inventories
                         .where(catalog_id: catalogs.select(:id))
                         .to_h { |inv| [ inv.catalog_id, inv.available_stock ] }

    ::AdditionalOrders::OrderForm.new(
      location: @location,
      catalogs: catalogs,
      stock_map: stock_map,
      search_query: params[:search_query],
      submitted: submitted
    )
  end
end
