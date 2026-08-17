# frozen_string_literal: true

class CatalogPricesController < ApplicationController
  before_action :set_catalog
  before_action :validate_kind

  def edit
    @kind = params[:kind]
    @catalog_price = @catalog.price_by_kind(@kind) || @catalog.prices.build(kind: @kind)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def update
    @kind = params[:kind]
    CatalogPrice.create_with_history!(catalog: @catalog, kind: @kind, price: catalog_price_params[:price])
    @catalog.reload

    respond_to do |format|
      format.turbo_stream
    end
  rescue ActiveRecord::RecordInvalid => e
    render turbo_stream: turbo_stream.replace(
      Catalogs::PriceForm::Component::MODAL_FRAME_ID,
      Catalogs::PriceForm::Component.new(
        catalog: @catalog,
        catalog_price: e.record,
        kind: @kind
      )
    ), status: :unprocessable_entity
  end

  private

  def validate_kind
    head :not_found unless CatalogPrice.kinds.key?(params[:kind])
  end

  def set_catalog
    @catalog = Catalog
                 .eager_load(:discontinuation)
                 .preload(:prices)
                 .find(params[:catalog_id])
  end

  def catalog_price_params
    params.require(:catalog_price).permit(:price)
  end
end
