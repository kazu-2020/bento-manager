# frozen_string_literal: true

require "test_helper"

class Pos::Sales::NewFormComponentTest < ViewComponent::TestCase
  include GhostFormCorrespondenceHelper

  fixtures :locations, :catalogs, :catalog_prices, :catalog_pricing_rules,
           :daily_inventories, :coupons, :discounts

  setup do
    @location = locations(:city_hall)
  end

  # コントローラテストは ghost_cart[...] を手書きして POST するため、ブラウザが
  # 実際にそのキーを組み立てられるかは通らない。詳細は
  # test/support/ghost_form_correspondence_helper.rb を参照
  test "販売画面の入力は、すべて Ghost Form 側に ghost_ 付きの受け皿を持つ" do
    result = render_inline(
      Pos::Sales::NewForm::Component.new(location: @location, form: build_cart_form)
    )

    # 商品カード・クーポン・顧客区分の 3 系統が母集合に出ているはず
    assert_ghost_inputs_correspond(result, minimum: 3)
  end

  private

  # 検査するのは input の名前だけなので、コントローラの eager loading や並び順は
  # 写さない。写すと、関係の無いクエリ変更のたびに追随を迫られる
  def build_cart_form
    ::Sales::CartForm.new(
      location: @location,
      inventories: @location.today_inventories.includes(:catalog),
      discounts: Discount.active
    )
  end
end
