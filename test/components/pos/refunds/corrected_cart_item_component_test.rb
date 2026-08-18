# frozen_string_literal: true

require "test_helper"

class Pos::Refunds::CorrectedCartItemComponentTest < ViewComponent::TestCase
  fixtures :catalogs, :catalog_prices

  test "単価は設定されていれば通貨表記で表示し、なければ表示しない" do
    render_inline(component_for(catalogs(:salad)))

    assert_includes rendered_content, "¥250"

    no_price = Catalog.create!(name: "価格未設定サラダ", kana: "カカクミセッテイサラダ", category: :side_menu)
    render_inline(component_for(no_price))

    assert_no_match(/¥/, rendered_content)
  end

  # 単価は同じカードの中で表示の有無判定と本文の 2 箇所から参照される。素直に書くと
  # 商品 1 つにつき 2 回引くことになり、価格が読み込み済みでない場面ではそのまま
  # 問い合わせ 2 本になる
  test "単価は 1 枚のカードにつき 1 回しか引かない" do
    catalog = Catalog.find(catalogs(:salad).id)

    assert_queries_match(/FROM ["`]catalog_prices["`]/, count: 1) do
      render_inline(component_for(catalog))
    end
  end

  private

  def component_for(catalog)
    item = Refunds::CorrectedItem.new(
      catalog: catalog, quantity: 1, original_quantity: 1, max_quantity: 3
    )
    Pos::Refunds::CorrectedCartItem::Component.new(item: item)
  end
end
