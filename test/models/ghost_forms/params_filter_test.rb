# frozen_string_literal: true

require "test_helper"

module GhostForms
  class ParamsFilterTest < ActiveSupport::TestCase
    # 実物の宣言を参照する。写すとフォーム側の変更に気付けない
    CART_SHAPE = ::Sales::CartForm::SUBMITTED_PARAMS_SHAPE

    def filter(raw, **shape)
      ParamsFilter.call(ActionController::Parameters.new(cart: raw)[:cart], **shape)
    end

    test "keeps the shape the cart form actually reads" do
      filtered = filter(
        {
          "12" => { "quantity" => "3" },
          "customer_type" => "citizen",
          "coupon" => { "5" => { "quantity" => "1" } }
        },
        **CART_SHAPE
      )

      assert_equal(
        {
          "12" => { "quantity" => "3" },
          "customer_type" => "citizen",
          "coupon" => { "5" => { "quantity" => "1" } }
        },
        filtered
      )
    end

    test "reads back with both string and symbol keys" do
      filtered = filter({ "12" => { "quantity" => "3" } })

      assert_equal "3", filtered["12"]["quantity"]
      assert_equal "3", filtered[:"12"][:quantity]
    end

    test "drops groups whose key is not an id" do
      filtered = filter({ "abc" => { "quantity" => "1" }, "12" => { "quantity" => "2" } })

      assert_equal({ "12" => { "quantity" => "2" } }, filtered)
    end

    test "drops collection entries whose key is not an id" do
      filtered = filter({ "coupon" => { "abc" => { "quantity" => "1" }, "5" => { "quantity" => "2" } } }, **CART_SHAPE)

      assert_equal({ "coupon" => { "5" => { "quantity" => "2" } } }, filtered)
    end

    test "keeps every declared group a hash so the forms can dig safely" do
      filtered = filter({ "12" => "ハッシュではなく文字列", "13" => [ "配列" ] })

      assert_equal({}, filtered)
      assert_nil filtered.dig("12", "quantity")
    end

    test "keeps every collection entry a hash so the forms can index safely" do
      filtered = filter({ "coupon" => { "5" => 3, "6" => "文字列", "7" => { "quantity" => "1" } } }, **CART_SHAPE)

      assert_equal({ "coupon" => { "7" => { "quantity" => "1" } } }, filtered)
      assert_nil filtered["coupon"]["5"]
    end

    test "drops declared scalars carrying the wrong type" do
      filtered = filter({ "customer_type" => { "nested" => "1" } }, **CART_SHAPE)

      assert_equal({}, filtered)
    end

    test "drops nesting deeper than the declared shape" do
      filtered = filter({ "12" => { "quantity" => { "nested" => "1" } } })

      assert_equal({ "12" => {} }, filtered)
    end

    test "drops leaves that do not respond to the coercions the forms apply" do
      filtered = filter({ "12" => { "quantity" => true, "stock" => nil, "selected" => "1" } })

      assert_equal({ "12" => { "selected" => "1" } }, filtered)
    end

    test "returns an empty hash when the node is missing or not a hash" do
      assert_equal({}, ParamsFilter.call(nil))
      assert_equal({}, filter("文字列"))
      assert_equal({}, filter([ "配列" ]))
    end
  end
end
