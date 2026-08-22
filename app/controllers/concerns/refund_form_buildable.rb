# frozen_string_literal: true

module RefundFormBuildable
  extend ActiveSupport::Concern
  include SubmittedParamsFilterable

  # 差額精算の入口はこの並びで守る。確定用と Ghost Form の 2 つの入口が同じ
  # フォームを組み立てるため（ghost-form-pattern.md ルール 3）、並べる責務を
  # コントローラーに置くと片方だけ素通しになる
  #
  # 拠点を絞るのは Ghost Form と直交する関心事だが、@location が無いとこの並びは
  # 成立しない。include 順をコントローラー側の記述順に委ねると書き忘れた側だけが
  # 素通しになるため、依存としてここで宣言する（Concern が先に include するので
  # callback は set_location > set_sale > ガード群の順を保つ）
  include PosLocationScoped

  included do
    before_action :set_sale
    before_action :redirect_if_voided
    before_action :redirect_unless_sold_today
    before_action :set_inventories
  end

  private

  # 明細側の catalog にも PRICING_ASSOCIATIONS を載せる。修正カートの母集合は「元の販売の商品 + 当日の
  # 在庫」なので、当日の在庫に無い商品を売っていた販売では、在庫側の catalog をいくら
  # 揃えても明細の分の価格が読み込み済みにならない。加えて RefundForm#catalog_lookup
  # は両方にある商品では明細側を採るため、在庫側だけでは取りこぼす。
  #
  # クーポンは RefundForm（元の枚数）と Refunds::Preview（返却枚数）の両方が読む。
  # ここで読んでおかないと、数量入力を動かすたびの再描画ごとに問い合わせが増える
  def set_sale
    @sale = @location.sales
                     .preload(items: [ { catalog: Catalog::PRICING_ASSOCIATIONS }, :catalog_price ], sale_discounts: :discount)
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
    @inventories = @location.today_inventories.for_cart
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
