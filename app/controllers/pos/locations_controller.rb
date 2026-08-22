# frozen_string_literal: true

module Pos
  class LocationsController < ApplicationController
    include PosLocationScoped

    # 一覧は拠点を 1 つに絞らない。active で絞る責務は @locations 側が持つ
    skip_before_action :set_location, only: :index

    def index
      @locations = Location.active.preload(:today_inventories).order(:name)
    end

    def show
      if @location.has_today_inventory?
        redirect_to new_pos_location_sale_path(@location)
      else
        redirect_to new_pos_location_daily_inventory_path(@location)
      end
    end

    private

    # POS で唯一、拠点そのものがリソースになる画面
    def location_param_key
      :id
    end
  end
end
