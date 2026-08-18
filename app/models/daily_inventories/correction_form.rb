# frozen_string_literal: true

module DailyInventories
  class CorrectionForm
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Rails.application.routes.url_helpers

    include ItemSelectable
    include ::GhostForms::SubmissionReadable

    # submitted は全キーが商品 ID の group（GhostForms::ParamsFilter が使う）
    SUBMITTED_PARAMS_SHAPE = {}.freeze

    attr_reader :items, :location, :registered_count, :search_query

    validate :at_least_one_item_selected

    # items の出どころは submitted と既存在庫の 2 通りある（submitted.absent? で決まる）。
    # submitted 自体も受け取るのは、壊れた送信を SubmissionReadable が差し戻すため。
    # 通すと bulk_recreate が既存在庫を破壊的に作り直す（理由は GhostForms::Submission）
    def initialize(location:, items:, search_query: nil, submitted: ::GhostForms::Submission.absent)
      @location = location
      @search_query = search_query&.strip.presence
      @items = items
      @submitted = submitted
      @registered_count = 0
    end

    def save
      return false unless valid?

      result = DailyInventory.bulk_recreate(location: location, items: selected_items)

      if result == :sales_already_started
        errors.add(:base, :sales_already_started)
        return false
      end

      @registered_count = result

      if @registered_count.positive?
        true
      else
        errors.add(:base, :save_failed)
        false
      end
    end

    def form_with_options
      {
        url: pos_location_daily_inventories_correction_path(location),
        method: :post
      }
    end

    def form_state_options
      {
        url: pos_location_daily_inventories_corrections_form_state_path(location),
        method: :post
      }
    end

    private

    def at_least_one_item_selected
      errors.add(:base, :no_items_selected) unless selected_count.positive?
    end
  end
end
