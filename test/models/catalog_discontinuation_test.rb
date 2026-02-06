require "test_helper"

class CatalogDiscontinuationTest < ActiveSupport::TestCase
  fixtures :catalogs, :catalog_discontinuations

  test "validations" do
    @subject = CatalogDiscontinuation.new(
      catalog: catalogs(:daily_bento_a),
      discontinued_at: Time.current,
      reason: "テスト提供終了"
    )

    must validate_uniqueness_of(:catalog_id)
    must validate_presence_of(:discontinued_at)
    must validate_presence_of(:reason)
  end

  test "associations" do
    @subject = CatalogDiscontinuation.new

    must belong_to(:catalog)
  end
end
