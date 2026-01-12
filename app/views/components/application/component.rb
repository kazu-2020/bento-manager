# frozen_string_literal: true

module Application
  class Component < ViewComponent::Base
    def component(name, *args, **kwargs, &block)
      helpers.component(name, *args, **kwargs, &block)
    end
  end
end
