# frozen_string_literal: true

module Catalogs
  class DiscontinuationsController < ApplicationController
    before_action :set_catalog

    def new
      respond_to do |format|
        format.turbo_stream
      end
    end

    def create
      if @catalog.discontinued?
        return redirect_to catalogs_path, alert: t("catalogs.discontinuations.already_discontinued")
      end

      discontinuation = @catalog.build_discontinuation(
        discontinued_at: Time.current,
        reason: params[:reason].presence || t("catalogs.discontinuations.default_reason")
      )

      if discontinuation.save
        redirect_to catalog_path(@catalog)
      else
        redirect_to catalog_path(@catalog)
      end
    end

    private

    def set_catalog
      @catalog = Catalog
                   .eager_load(:discontinuation)
                   .find(params[:catalog_id])
    end
  end
end
