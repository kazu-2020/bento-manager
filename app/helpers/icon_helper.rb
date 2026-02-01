# frozen_string_literal: true

module IconHelper
  def icon(name, size: :md, extra_class: nil)
    render Icon::Component.new(name: name, size: size, extra_class: extra_class)
  end
end
