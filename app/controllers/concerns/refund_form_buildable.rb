# frozen_string_literal: true

module RefundFormBuildable
  extend ActiveSupport::Concern
  include SubmittedParamsFilterable

  # 差額精算の入口はこの並びで守る。確定用と Ghost Form の 2 つの入口が同じ
  # フォームを組み立てるため（ghost-form-pattern.md ルール 3）、並べる責務を
  # コントローラーに置くと片方だけ素通しになる
  included do
    before_action :set_location
    before_action :set_sale
    before_action :redirect_if_voided
    before_action :redirect_unless_sold_today
    before_action :set_inventories
  end

  private

  def set_location
    @location = Location.active.find(params[:location_id])
  end

  # 修正カートの母集合は元の販売の商品を先に採るため（RefundForm#catalog_lookup）、
  # 明細側の catalog にも価格を載せておく。在庫側の catalog にだけ載せても、
  # 同じ商品を両方が持つときは明細側が勝って読み込み済みにならない
  def set_sale
    @sale = @location.sales
                     .preload(items: [ { catalog: :prices }, :catalog_price ])
                     .find(params[:sale_id])
  end

  # もう触れない販売は、開こうとしても送信しても 422 で差し戻さずリダイレクトする。
  # 修正カートの母集合は当日在庫と元の販売なので、再描画しても
  # 何を送っても通らない画面が残るだけになる
  def redirect_if_voided
    return unless @sale.voided?

    redirect_to_sales_history("pos.locations.refunds.already_voided")
  end

  def redirect_unless_sold_today
    return if @sale.sold_today?

    redirect_to_sales_history("pos.locations.refunds.not_todays_sale")
  end

  # もう触れない販売を差し戻す先。理由は alert で伝える
  #
  # @param alert_key [String] 文言の i18n キー
  def redirect_to_sales_history(alert_key)
    redirect_to pos_location_sales_history_index_path(@location), alert: t(alert_key)
  end

  def set_inventories
    @inventories = @location
                      .today_inventories
                      .eager_load(:catalog)
                      .preload(catalog: :prices)
                      .merge(Catalog.category_order)
  end

  def build_form(submitted = ::GhostForms::Submission.absent)
    ::Refunds::RefundForm.new(
      sale: @sale,
      location: @location,
      inventories: @inventories,
      submitted: submitted
    )
  end
end
