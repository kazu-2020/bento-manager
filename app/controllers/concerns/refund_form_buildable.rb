# frozen_string_literal: true

module RefundFormBuildable
  extend ActiveSupport::Concern

  private

  def set_location
    @location = Location.active.find(params[:location_id])
  end

  def set_sale
    @sale = @location.sales
                     .preload(items: :catalog)
                     .find(params[:sale_id])
  end

  def set_inventories
    @inventories = @location
                      .today_inventories
                      .eager_load(catalog: :prices)
                      .merge(Catalog.category_order)
  end

  def build_form(submitted = {})
    ::Refunds::RefundForm.new(
      sale: @sale,
      location: @location,
      inventories: @inventories,
      submitted: submitted
    )
  end

  def submitted_params(key)
    return {} unless params[key]

    params[key].to_unsafe_h
  end
end
