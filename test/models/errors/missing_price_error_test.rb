# frozen_string_literal: true

require "test_helper"

class Errors::MissingPriceErrorTest < ActiveSupport::TestCase
  test "単一の欠損価格で初期化できる" do
    error = Errors::MissingPriceError.new([ { catalog_name: "弁当A", price_kind: "regular" } ])

    assert_equal 1, error.missing_prices.length
    assert_equal "弁当A", error.missing_prices.first[:catalog_name]
    assert_equal "regular", error.missing_prices.first[:price_kind]
    assert_match(/弁当A/, error.message)
    assert_match(/regular/, error.message)
  end

  test "catalog_id を含む欠損価格で初期化できる" do
    error = Errors::MissingPriceError.new([ { catalog_id: 123, catalog_name: "弁当A", price_kind: "regular" } ])

    assert_equal 123, error.missing_prices.first[:catalog_id]
    assert_equal "弁当A", error.missing_prices.first[:catalog_name]
    assert_equal "regular", error.missing_prices.first[:price_kind]
  end

  test "複数の欠損価格で初期化できる" do
    missing = [
      { catalog_id: 1, catalog_name: "弁当A", price_kind: "regular" },
      { catalog_id: 2, catalog_name: "サラダ", price_kind: "bundle" }
    ]
    error = Errors::MissingPriceError.new(missing)

    assert_equal 2, error.missing_prices.length
    assert_match(/弁当A/, error.message)
    assert_match(/サラダ/, error.message)
    assert_match(/価格設定エラー:/, error.message)
  end

  test "単一の欠損価格のメッセージにはプレフィックスがない" do
    error = Errors::MissingPriceError.new([ { catalog_name: "弁当A", price_kind: "regular" } ])

    assert_equal "商品「弁当A」に価格種別「regular」の価格が設定されていません", error.message
  end

  test "複数の欠損価格のメッセージにはプレフィックスがある" do
    missing = [
      { catalog_id: 1, catalog_name: "弁当A", price_kind: "regular" },
      { catalog_id: 2, catalog_name: "サラダ", price_kind: "bundle" }
    ]
    error = Errors::MissingPriceError.new(missing)

    assert error.message.start_with?("価格設定エラー:")
    assert_includes error.message, "弁当A"
    assert_includes error.message, "サラダ"
  end

  test "空配列で初期化するとデフォルトメッセージを返す" do
    error = Errors::MissingPriceError.new([])

    assert_equal [], error.missing_prices
    assert_equal "価格設定エラー", error.message
  end

  test "StandardError を継承している" do
    error = Errors::MissingPriceError.new([ { catalog_name: "弁当A", price_kind: "regular" } ])

    assert_kind_of StandardError, error
  end
end
