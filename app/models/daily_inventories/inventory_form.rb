# frozen_string_literal: true

module DailyInventories
  class InventoryForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers

    include ItemSelectable
    include ::GhostForms::SubmissionReadable

    # submitted は全キーが商品 ID の group（GhostForms::ParamsFilter が使う）
    SUBMITTED_PARAMS_SHAPE = {}.freeze

    attr_reader :items, :location, :created_count, :search_query

    validate :at_least_one_item_selected

    # submitted 自体も受け取るのは、壊れた送信を SubmissionReadable が差し戻すため
    def initialize(location:, items:, search_query: nil, submitted: ::GhostForms::Submission.absent)
      @location = location
      @search_query = search_query&.strip.presence
      @items = items
      @submitted = submitted
      @created_count = 0
    end

    def save
      return false unless valid?

      @created_count = DailyInventory.bulk_create(location: location, items: selected_items)

      if @created_count.positive?
        true
      else
        errors.add(:base, :save_failed)
        false
      end
    end

    def form_with_options
      {
        url: pos_location_daily_inventories_path(location),
        method: :post
      }
    end

    def form_state_options
      {
        url: pos_location_daily_inventories_form_state_path(location),
        method: :post
      }
    end

    private

    def at_least_one_item_selected
      # 読めない送信では「1 件も無い」のか「捨てられただけ」なのか判定しようがない
      return if submitted_unreadable?

      errors.add(:base, :no_items_selected) unless selected_count.positive?
    end
  end
end
