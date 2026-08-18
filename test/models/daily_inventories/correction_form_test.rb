# frozen_string_literal: true

require "test_helper"

module DailyInventories
  class CorrectionFormTest < ActiveSupport::TestCase
    include GhostFormSubmissionHelper

    fixtures :catalogs

    setup do
      @location = Location.create!(name: "訂正フォームテスト販売先", status: :active)
      @bento_a = catalogs(:daily_bento_a)
      @catalogs = [ @bento_a ]
      DailyInventory.create!(
        location: @location, catalog: @bento_a,
        inventory_date: Date.current, stock: 10, reserved_stock: 0
      )
    end

    def submission_form
      CorrectionForm
    end

    def build(items:, submitted:)
      CorrectionForm.new(location: @location, items: items, submitted: submitted)
    end

    def items_from_existing_inventories
      ItemBuilder.from_inventories(@catalogs, @location.today_inventories.index_by(&:catalog_id))
    end

    test "未送信の初回描画は、既存在庫からの初期値でも壊れた送信として扱わない" do
      form = build(items: items_from_existing_inventories, submitted: ::GhostForms::Submission.absent)

      assert_predicate form, :valid?
    end

    test "送信されたのに中身が残らなければ、items が既存在庫由来でも差し戻す" do
      # コントローラーが初期値の分岐を誤り、既存在庫から items を組んでしまった形。
      # これを通すと bulk_recreate が既存在庫を破壊的に作り直す
      form = build(
        items: items_from_existing_inventories,
        submitted: submission({ "abc" => { "selected" => "1", "stock" => "1" } })
      )

      assert_not form.valid?
      assert form.errors.added?(:base, :unreadable_submission)
      # 「選択してください」を重ねると、パラメータが捨てられたことが操作ミスに見える
      assert_not form.errors.added?(:base, :no_items_selected)
    end

    test "読める送信は通常どおり検証される" do
      submitted = submission({ @bento_a.id.to_s => { "selected" => "1", "stock" => "20" } })
      form = build(items: ItemBuilder.from_params(@catalogs, submitted.values), submitted: submitted)

      assert_predicate form, :valid?
    end

    test "読める送信で1件も選択されていなければ、壊れた送信ではなく未選択として案内する" do
      submitted = submission({ @bento_a.id.to_s => { "selected" => "0", "stock" => "10" } })
      form = build(items: ItemBuilder.from_params(@catalogs, submitted.values), submitted: submitted)

      assert_not form.valid?
      assert form.errors.added?(:base, :no_items_selected)
      assert_not form.errors.added?(:base, :unreadable_submission)
    end
  end
end
