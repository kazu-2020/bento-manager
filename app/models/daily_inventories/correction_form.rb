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

    # items の出どころは submitted と既存在庫の 2 通りあり、どちらから組むかは
    # submitted.absent? だけで決まる。分岐も既存在庫の取得もフォームが持つ。
    # コントローラーに置くと、送信ありなのに既存在庫から組んだ items という
    # 状態が作れてしまい、通せば bulk_recreate が既存在庫を破壊的に作り直す
    # （理由は GhostForms::Submission）
    def initialize(location:, catalogs:, search_query: nil, submitted: ::GhostForms::Submission.absent)
      @location = location
      @catalogs = catalogs
      @search_query = search_query&.strip.presence
      @submitted = submitted
      @items = build_items
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

    # 既存在庫を引くのは初回描画だけ。Ghost Form 経由の submitted は absent に
    # ならないので、渡し込みにすると毎キーストロークで捨てるだけの問合せが走る
    def build_items
      return ItemBuilder.from_params(@catalogs, submitted.values) unless submitted.absent?

      ItemBuilder.from_inventories(@catalogs, location.today_inventories.index_by(&:catalog_id))
    end

    def at_least_one_item_selected
      # 読めない送信では「1 件も無い」のか「捨てられただけ」なのか判定しようがない
      return if submitted_unreadable?

      errors.add(:base, :no_items_selected) unless selected_count.positive?
    end
  end
end
