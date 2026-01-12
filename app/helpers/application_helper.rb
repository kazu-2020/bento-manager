module ApplicationHelper
  # ViewComponentの簡潔な呼び出しを提供
  # 使用例:
  #   <%= component "status_badge", status: :active %>
  #   <%= component "location_card", collection: @locations %>
  def component(name, *args, collection: nil, **kwargs, &block)
    component_class = name.to_s.camelize.constantize::Component
    if collection
      render(component_class.with_collection(collection, **kwargs), &block)
    else
      render(component_class.new(*args, **kwargs), &block)
    end
  end
end
