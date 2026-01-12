module ApplicationHelper
  # ViewComponentの簡潔な呼び出しを提供
  # 使用例: <%= component "status_badge", status: :active %>
  def component(name, *args, **kwargs, &block)
    component_class = name.to_s.camelize.constantize::Component
    render(component_class.new(*args, **kwargs), &block)
  end
end
