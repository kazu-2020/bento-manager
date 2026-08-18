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

    def build(submitted: ::GhostForms::Submission.absent)
      CorrectionForm.new(location: @location, catalogs: @catalogs, submitted: submitted)
    end

    test "未送信の初回描画は、既存在庫から初期値を組み、壊れた送信として扱わない" do
      form = build

      assert_predicate form, :valid?
      assert_equal [ 10 ], form.selected_items.map(&:stock)
    end

    test "送信されたのに中身が残らなければ差し戻し、既存在庫からは組み直さない" do
      # 通すと bulk_recreate が既存在庫を破壊的に作り直す
      form = build(submitted: submission({ "abc" => { "selected" => "1", "stock" => "1" } }))

      assert_not form.valid?
      assert form.errors.added?(:base, :unreadable_submission)
      # 「選択してください」を重ねると、パラメータが捨てられたことが操作ミスに見える
      assert_not form.errors.added?(:base, :no_items_selected)
      assert_empty form.selected_items
    end

    test "読める送信は通常どおり検証される" do
      form = build(submitted: submission({ @bento_a.id.to_s => { "selected" => "1", "stock" => "20" } }))

      assert_predicate form, :valid?
      assert_equal [ 20 ], form.selected_items.map(&:stock)
    end

    test "読める送信で1件も選択されていなければ、壊れた送信ではなく未選択として案内する" do
      form = build(submitted: submission({ @bento_a.id.to_s => { "selected" => "0", "stock" => "10" } }))

      assert_not form.valid?
      assert form.errors.added?(:base, :no_items_selected)
      assert_not form.errors.added?(:base, :unreadable_submission)
    end
  end
end
