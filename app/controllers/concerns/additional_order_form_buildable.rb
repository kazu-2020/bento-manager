# frozen_string_literal: true

module AdditionalOrderFormBuildable
  extend ActiveSupport::Concern
  # @location が無いと build_form の today_inventories が引けない。コントローラー側の
  # include 順に委ねると書き忘れた側だけが素通しになるため、依存として宣言する
  include PosLocationScoped
  include SubmittedParamsFilterable

  private

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
