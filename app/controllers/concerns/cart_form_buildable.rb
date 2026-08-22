# frozen_string_literal: true

module CartFormBuildable
  extend ActiveSupport::Concern
  include SubmittedParamsFilterable

  # 確定用と Ghost Form の 2 つの入口が同じフォームを組み立てるため
  # （ghost-form-pattern.md ルール 3）、その材料を揃える並びは concern が持つ。
  # ここに並ぶのは読み込みだけで、画面に入れるかどうかを決めるガードは
  # 入口ごとに違うのでコントローラーに残す（例: SalesController#redirect_unless_inventories）
  #
  # 拠点を絞るのは Ghost Form と直交する関心事だが、@location が無いとこの並びは
  # 成立しない。include 順をコントローラー側の記述順に委ねると書き忘れた側だけが
  # 素通しになるため、依存としてここで宣言する（Concern が先に include するので
  # callback は set_location > set_inventories > set_discounts の順を保つ）
  include PosLocationScoped

  included do
    before_action :set_inventories
    before_action :set_discounts
  end

  private

  def set_inventories
    @inventories = @location.today_inventories.for_cart
  end

  def set_discounts
    @discounts = Discount.active_with_discountable
  end

  def build_form(submitted = ::GhostForms::Submission.absent)
    ::Sales::CartForm.new(
      location: @location,
      inventories: @inventories,
      discounts: @discounts,
      submitted: submitted
    )
  end
end
