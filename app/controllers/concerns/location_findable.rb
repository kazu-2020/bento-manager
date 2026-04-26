# frozen_string_literal: true

module LocationFindable
  private

  def find_location
    if params[:location_id].present?
      Location.find(params[:location_id])
    else
      Location.display_order.first
    end
  end
end
