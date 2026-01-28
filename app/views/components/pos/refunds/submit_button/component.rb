# frozen_string_literal: true

module Pos
  module Refunds
    module SubmitButton
      class Component < Application::Component
        def initialize(form:)
          @form = form
        end

        attr_reader :form

        delegate :has_selected_items?, to: :form

        def disabled?
          !has_selected_items?
        end
      end
    end
  end
end
