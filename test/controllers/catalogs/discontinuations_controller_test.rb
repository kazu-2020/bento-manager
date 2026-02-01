# frozen_string_literal: true

require "test_helper"

module Catalogs
  class DiscontinuationsControllerTest < ActionDispatch::IntegrationTest
    fixtures :employees, :catalogs

    setup do
      @employee = employees(:verified_employee)
      @catalog = catalogs(:daily_bento_a)
      @discontinued_catalog = catalogs(:discontinued_bento)
      @discontinued_catalog.create_discontinuation!(
        discontinued_at: Time.current,
        reason: "テスト用提供終了"
      )
    end

    # ============================================================
    # Admin認証時のテスト
    # ============================================================

    test "admin can access new (discontinue confirmation modal)" do
      login_as_employee(@employee)
      get new_catalog_discontinuation_path(@catalog), as: :turbo_stream
      assert_response :success
    end

    test "admin can create discontinuation (discontinue catalog)" do
      login_as_employee(@employee)
      assert_no_difference("Catalog.count") do
        assert_difference("CatalogDiscontinuation.count") do
          post catalog_discontinuation_path(@catalog)
        end
      end
      assert_redirected_to catalog_path(@catalog)
      @catalog.reload
      assert @catalog.discontinued?
    end

    # ============================================================
    # Employee認証時のテスト
    # ============================================================

    test "employee can access new (discontinue confirmation modal)" do
      login_as_employee(@employee)
      get new_catalog_discontinuation_path(@catalog), as: :turbo_stream
      assert_response :success
    end

    test "employee can create discontinuation (discontinue catalog)" do
      login_as_employee(@employee)
      assert_no_difference("Catalog.count") do
        assert_difference("CatalogDiscontinuation.count") do
          post catalog_discontinuation_path(@catalog)
        end
      end
      assert_redirected_to catalog_path(@catalog)
      @catalog.reload
      assert @catalog.discontinued?
    end

    # ============================================================
    # 未認証時のテスト
    # ============================================================

    test "unauthenticated user is redirected to login on new" do
      get new_catalog_discontinuation_path(@catalog)
      assert_redirected_to "/employee/login"
    end

    test "unauthenticated user is redirected to login on create" do
      assert_no_difference("CatalogDiscontinuation.count") do
        post catalog_discontinuation_path(@catalog)
      end
      assert_redirected_to "/employee/login"
      @catalog.reload
      assert_not @catalog.discontinued?
    end

    # ============================================================
    # 特有のテスト
    # ============================================================

    test "create for already discontinued catalog redirects with alert" do
      login_as_employee(@employee)
      assert_no_difference("CatalogDiscontinuation.count") do
        post catalog_discontinuation_path(@discontinued_catalog)
      end
      assert_redirected_to catalogs_path
      assert_equal I18n.t("catalogs.discontinuations.already_discontinued"), flash[:alert]
    end

    test "create with reason saves the reason" do
      login_as_employee(@employee)
      post catalog_discontinuation_path(@catalog), params: { reason: "季節終了のため" }
      assert_redirected_to catalog_path(@catalog)
      @catalog.reload
      assert @catalog.discontinued?
      assert_equal "季節終了のため", @catalog.discontinuation.reason
    end

    test "create without reason uses default reason" do
      login_as_employee(@employee)
      post catalog_discontinuation_path(@catalog)
      assert_redirected_to catalog_path(@catalog)
      @catalog.reload
      assert @catalog.discontinued?
      assert_equal I18n.t("catalogs.discontinuations.default_reason"), @catalog.discontinuation.reason
    end
  end
end
