# frozen_string_literal: true

class ExampleComponentPreview < ViewComponent::Preview
  def default
    render(Example::Component.new(title: "title"))
  end
end
