# frozen_string_literal: true

require "test_helper"

module Locations
  class SelectorComponentTest < ViewComponent::TestCase
    def setup
      @city_hall = Location.new(id: 1, name: "市役所", status: :active)
      @prefectural_office = Location.new(id: 2, name: "県庁", status: :active)
    end

    test "販売先を選ぶと、選択中の販売先を差し替えた画面へ切り替わる" do
      result = render_inline(
        Locations::Selector::Component.new(
          locations: [ @city_hall, @prefectural_office ],
          selected: @prefectural_office,
          path_builder: ->(loc_id) { "/sales_histories?location_id=#{loc_id}" }
        )
      )

      select = result.css("select").first
      options = result.css("option")

      assert_equal [ "市役所", "県庁" ], options.map { |o| o.text.strip }
      assert_equal [ "/sales_histories?location_id=1", "/sales_histories?location_id=2" ],
                   options.map { |o| o["value"] }
      assert_equal [ "県庁" ], options.select { |o| o["selected"] }.map { |o| o.text.strip }

      # 遷移は選択と同時に起きる。CSP 下で動く唯一の手段なので配線ごと固定する（#248）
      assert_equal "select-navigate", select["data-controller"]
      assert_equal "change->select-navigate#visit", select["data-action"]

      # 見出しもラベル要素も持たないので、読み上げの手がかりは aria-label だけ
      assert_equal "販売先を切り替える", select["aria-label"]
    end
  end
end
