# frozen_string_literal: true

class LocationCardComponentPreview < ViewComponent::Preview
  # @label 有効な販売先
  def active_location
    location = Location.new(id: 1, name: "市役所", status: :active)
    render(LocationCardComponent.new(location: location))
  end

  # @label 無効な販売先
  def inactive_location
    location = Location.new(id: 2, name: "旧庁舎", status: :inactive)
    render(LocationCardComponent.new(location: location))
  end

  # @param name text
  # @param status select { choices: [active, inactive] }
  def with_params(name: "販売先名", status: :active)
    location = Location.new(id: 1, name: name, status: status.to_sym)
    render(LocationCardComponent.new(location: location))
  end
end
