# frozen_string_literal: true

module Catalogs
  class FormFieldsController < ApplicationController
    def show
      @category = params[:category]

      respond_to do |format|
        format.turbo_stream
      end
    end
  end
end
