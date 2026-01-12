# frozen_string_literal: true

module Locations
  class LocationListComponentPreview < ViewComponent::Preview
    # @label 複数の販売先
    def with_locations
      locations = [
        Location.new(id: 1, name: "市役所", status: :active),
        Location.new(id: 2, name: "県庁", status: :active),
        Location.new(id: 3, name: "旧庁舎", status: :inactive)
      ]
      render(Locations::LocationList::Component.new(locations: locations))
    end

    # @label 販売先なし（空の状態）
    def empty
      render(Locations::LocationList::Component.new(locations: []))
    end

    # @label 1件のみ
    def single_location
      locations = [
        Location.new(id: 1, name: "本庁舎1F売店", status: :active)
      ]
      render(Locations::LocationList::Component.new(locations: locations))
    end
  end
end
