# Implementation Plan

## Project: sales-tracking-pos

**Feature Name**: 販売記録・追加発注・データ分析システム（POS + Analytics）
**Language**: ja
**Phase**: tasks-generated
**Generated**: 2026-01-04

---

## Task List

### Phase 1: Foundation & Database Setup

- [ ] 1. データベース基盤構築
- [x] 1.1 マルチデータベーススキーマ設定
  - primary database の設定確認（`config/database.yml`）
  - schema.rb のベースライン作成
  - _Requirements: 12.1_

- [x] 1.2 (P) マイグレーション基盤準備
  - Rails マイグレーション用のディレクトリ構造確認
  - タイムスタンプ付きマイグレーションファイル命名規則の確認
  - _Requirements: 12.1_

### Phase 2: Authentication & Authorization

- [ ] 2. Rodauth 認証システム構築
- [ ] 2.1 (P) Admin 認証セットアップ
  - Rodauth の Admin アカウント設定（メール、パスワードハッシュ）
  - ログイン/ログアウト機能の実装
  - セッション管理の設定
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 2.2 (P) Employee 認証セットアップ
  - Rodauth の Employee アカウント設定
  - 従業員用ログイン/ログアウト機能の実装
  - 従業員管理 CRUD（Admin のみアクセス可能）
  - _Requirements: 9.5, 9.6, 9.7, 9.8_

- [ ] 2.3 認可ロジック実装
  - Admin と Employee のロール分離
  - 管理画面へのアクセス制御（Admin のみ）
  - 販売画面へのアクセス制御（Employee 可能）
  - _Requirements: 9.9, 9.10_

### Phase 3: Core Domain Models - Location & Catalog

- [ ] 3. Location（販売先）ドメイン実装
- [ ] 3.1 (P) Location モデル作成
  - Location テーブルマイグレーション（id, name, status, created_at, updated_at）
  - status enum（active / inactive）の実装
  - default_scope で active のみ取得
  - deactivate/activate メソッド実装
  - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

- [ ] 3.2 (P) Location バリデーション実装
  - name の必須バリデーション
  - name の一意性バリデーション
  - _Requirements: 16.6_

- [ ] 3.3 (P) Location インデックス作成
  - idx_locations_name インデックス追加
  - _Requirements: 16.4_

- [ ] 4. Catalog（商品カタログ）ドメイン実装
- [ ] 4.1 (P) Catalog モデル作成
  - Catalog テーブルマイグレーション（id, name, category, description）
  - category enum（bento / side_menu）の実装
  - _Requirements: 1.1, 1.2, 1.4_

- [ ] 4.2 (P) CatalogPrice モデル作成
  - CatalogPrice テーブルマイグレーション（id, catalog_id, kind, price, effective_from, effective_until）
  - kind enum（regular / bundle）の実装
  - effective_from/effective_until による価格履歴管理
  - _Requirements: 1.1, 1.5, 14.1, 14.2_

- [ ] 4.3 (P) CatalogPricingRule モデル作成
  - CatalogPricingRule テーブルマイグレーション（id, target_catalog_id, price_kind, trigger_category, max_per_trigger, valid_from, valid_until）
  - セット価格適用ルールのロジック実装
  - applicable? メソッド実装
  - _Requirements: 14.3, 14.4, 14.5, 14.6_

- [ ] 4.4 (P) CatalogDiscontinuation モデル作成
  - CatalogDiscontinuation テーブルマイグレーション（id, catalog_id, discontinued_at, reason）
  - catalog_id のユニーク制約
  - _Requirements: 1.3_

- [ ] 4.5 (P) Catalog バリデーション実装
  - name のユニーク制約
  - category の必須バリデーション
  - price > 0 のバリデーション
  - _Requirements: 1.1, 1.4, 1.5_

- [ ] 4.6 (P) Catalog インデックス作成
  - idx_catalogs_name インデックス追加
  - idx_catalog_prices_catalog_kind インデックス追加
  - idx_catalog_pricing_rules_target インデックス追加
  - _Requirements: 1.4_

### Phase 4: Discount Domain

- [ ] 5. Discount（割引）ドメイン実装
- [ ] 5.1 (P) Discount 抽象モデル作成
  - Discount テーブルマイグレーション（id, discountable_type, discountable_id, name, valid_from, valid_until）
  - delegated_type パターン実装
  - applicable? メソッドの委譲
  - calculate_discount メソッド実装
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 5.2 (P) Coupon モデル作成
  - Coupon テーブルマイグレーション（id, description, amount_per_unit, max_per_bento_quantity）
  - applicable? メソッド実装（弁当が含まれるか判定）
  - max_applicable_quantity メソッド実装
  - calculate_discount メソッド実装
  - _Requirements: 13.4, 13.5, 13.6, 13.7_

- [ ] 5.3 (P) Discount バリデーション実装
  - name, valid_from, valid_until の必須バリデーション
  - amount_per_unit > 0 のバリデーション
  - max_per_bento_quantity >= 0 のバリデーション
  - _Requirements: 13.1, 13.2_

- [ ] 5.4 (P) Discount インデックス作成
  - idx_discounts_name_valid_from インデックス追加
  - _Requirements: 13.1_

### Phase 5: Inventory Domain

- [ ] 6. DailyInventory（日次在庫）ドメイン実装
- [ ] 6.1 DailyInventory モデル作成（Location, Catalog 依存）
  - DailyInventory テーブルマイグレーション（id, location_id, catalog_id, inventory_date, stock, reserved_stock, lock_version）
  - location_id, catalog_id の外部キー制約
  - (location_id, catalog_id, inventory_date) のユニーク制約
  - optimistic locking（lock_version）の設定
  - _Requirements: 2.1, 2.2, 2.4, 12.1, 12.2, 16.1_

- [ ] 6.2 DailyInventory バリデーション実装
  - stock >= 0, reserved_stock >= 0 のバリデーション
  - available_stock = stock - reserved_stock >= 0 の検証
  - location_id, catalog_id, inventory_date の必須バリデーション
  - _Requirements: 2.4, 12.4_

- [ ] 6.3 DailyInventory インデックス作成
  - idx_daily_inventories_location_catalog_date（UNIQUE: location_id, catalog_id, inventory_date）
  - idx_daily_inventories_location（INDEX: location_id）
  - _Requirements: 2.2, 2.6_

- [ ] 6.4 DailyInventory 在庫操作メソッド実装
  - decrement_stock メソッド（販売時の在庫減算）
  - increment_stock メソッド（返品時の在庫復元）
  - トランザクション管理
  - _Requirements: 3.4, 15.9, 12.5_

### Phase 6: Sales Domain - Core Models

- [ ] 7. Sale（販売記録）ドメイン実装
- [ ] 7.1 Sale モデル作成（Location, Employee 依存）
  - Sale テーブルマイグレーション（id, location_id, sale_datetime, customer_type, total_amount, final_amount, employee_id, status, voided_at, voided_by_employee_id, void_reason, corrected_from_sale_id）
  - location_id, employee_id の外部キー制約
  - status enum（completed / voided）の実装
  - customer_type enum（staff / citizen）の実装
  - _Requirements: 3.3, 3.5, 15.1, 15.2, 15.8, 16.1_

- [ ] 7.2 Sale バリデーション実装
  - location_id, sale_datetime, customer_type の必須バリデーション
  - total_amount >= 0, final_amount >= 0 のバリデーション
  - status が voided の場合、voided_at, voided_by_employee_id, void_reason が必須
  - _Requirements: 3.3, 15.8_

- [ ] 7.3 Sale インデックス作成
  - idx_sales_location_datetime（INDEX: location_id, sale_datetime）
  - idx_sales_datetime（INDEX: sale_datetime）
  - idx_sales_status（INDEX: status）
  - _Requirements: 3.3, 7.1, 15.1_

- [ ] 7.4 Sale void メソッド実装
  - void! メソッド（status を voided に変更、voided_at, voided_by_employee_id, void_reason を記録）
  - voided? メソッド
  - _Requirements: 15.1, 15.2, 15.8_

- [ ] 8. SaleItem（販売明細）モデル実装
- [ ] 8.1 SaleItem モデル作成（Sale, Catalog, CatalogPrice 依存）
  - SaleItem テーブルマイグレーション（id, sale_id, catalog_id, catalog_price_id, quantity, unit_price, line_total, sold_at）
  - sale_id, catalog_id, catalog_price_id の外部キー制約
  - _Requirements: 3.1, 3.2, 14.7_

- [ ] 8.2 SaleItem バリデーション実装
  - quantity > 0 のバリデーション
  - unit_price >= 0 のバリデーション
  - line_total = unit_price × quantity の整合性検証
  - _Requirements: 3.1, 3.2_

- [ ] 8.3 SaleItem インデックス作成
  - idx_sale_items_sale_id（INDEX: sale_id）
  - idx_sale_items_catalog_id（INDEX: catalog_id）
  - idx_sale_items_catalog_price_id（INDEX: catalog_price_id）
  - idx_sale_items_sale_catalog（INDEX: sale_id, catalog_id）
  - _Requirements: 3.1_

- [ ] 8.4 SaleItem after_create コールバック実装
  - 在庫減算ロジック（DailyInventory#decrement_stock 呼び出し）
  - トランザクション内での在庫確認
  - 在庫不足時のエラーハンドリング
  - _Requirements: 3.4, 3.7_

- [ ] 9. SaleDiscount（販売・割引中間テーブル）モデル実装
- [ ] 9.1 (P) SaleDiscount モデル作成
  - SaleDiscount テーブルマイグレーション（id, sale_id, discount_id, discount_amount）
  - sale_id, discount_id の外部キー制約
  - (sale_id, discount_id) のユニーク制約
  - _Requirements: 13.8, 13.9_

- [ ] 9.2 (P) SaleDiscount バリデーション実装
  - sale_id, discount_id, discount_amount の必須バリデーション
  - discount_amount >= 0 のバリデーション
  - 同じ割引の重複適用防止
  - _Requirements: 13.8_

- [ ] 9.3 (P) SaleDiscount インデックス作成
  - idx_sale_discounts_unique（UNIQUE: sale_id, discount_id）
  - _Requirements: 13.8_

### Phase 7: Sales Domain - Price Calculator

- [ ] 10. Sales::PriceCalculator（価格計算 PORO）実装
- [ ] 10.1 Sales::PriceCalculator クラス作成（Catalog, CatalogPrice, CatalogPricingRule, Discount 依存）
  - app/models/sales ディレクトリ作成
  - PriceCalculator クラスの基本構造
  - initialize メソッド（cart_items, discount_ids を受け取る）
  - _Requirements: 3.1, 3.2, 13.1, 14.1_

- [ ] 10.2 価格ルール適用ロジック実装
  - apply_pricing_rules メソッド（CatalogPricingRule#applicable? を判定）
  - セット価格適用条件の判定（弁当1個につきサラダ1個まで）
  - 単品価格とセット価格の使い分け
  - _Requirements: 14.3, 14.4, 14.5, 14.6_

- [ ] 10.3 割引適用ロジック実装
  - apply_discounts メソッド（Discount#applicable? を判定）
  - クーポン枚数の計算（弁当数 × max_per_bento_quantity）
  - 複数割引の合算
  - _Requirements: 13.4, 13.5, 13.6, 13.7_

- [ ] 10.4 calculate メソッド実装
  - Step 1: 価格ルール適用（CatalogPricingRule）
  - Step 2: 小計計算（unit_price × quantity）
  - Step 3: 割引適用（Discount#calculate_discount）
  - Step 4: 最終金額計算（total_amount - total_discount_amount）
  - 価格内訳の返却（item_details, discount_details, total_amount, final_amount）
  - _Requirements: 3.1, 3.2, 13.8, 14.7_

### Phase 8: Refund Domain

- [ ] 11. Refund（返金記録）ドメイン実装
- [ ] 11.1 Refund モデル作成（Sale, Employee 依存）
  - Refund テーブルマイグレーション（id, original_sale_id, corrected_sale_id, employee_id, refund_datetime, amount, reason）
  - original_sale_id, corrected_sale_id, employee_id の外部キー制約
  - _Requirements: 15.3, 15.7, 15.10, 15.12_

- [ ] 11.2 Refund バリデーション実装
  - original_sale_id, refund_datetime, amount の必須バリデーション
  - amount >= 0 のバリデーション
  - _Requirements: 15.10_

- [ ] 11.3 Refund インデックス作成
  - idx_refunds_original_sale（INDEX: original_sale_id）
  - idx_refunds_corrected_sale（INDEX: corrected_sale_id）
  - _Requirements: 15.3_

- [ ] 11.4 返品・返金処理ロジック実装
  - 元の Sale を void（status = voided, voided_at, void_reason を記録）
  - 返品分を除いた商品で新規 Sale を作成（corrected_from_sale_id を設定）
  - 価格ルール・割引を再評価（Sales::PriceCalculator 呼び出し）
  - 差額を返金額として計算（original.final_amount - corrected.final_amount）
  - Refund レコード作成
  - 在庫復元（DailyInventory#increment_stock 呼び出し）
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.9, 15.11_

### Phase 9: Additional Order Domain

- [ ] 12. AdditionalOrder（追加発注）ドメイン実装
- [ ] 12.1 AdditionalOrder モデル作成（Location, Catalog, Employee 依存）
  - AdditionalOrder テーブルマイグレーション（id, location_id, catalog_id, order_date, order_time, quantity, employee_id）
  - location_id, catalog_id, employee_id の外部キー制約
  - _Requirements: 5.1, 5.2, 16.1_

- [ ] 12.2 AdditionalOrder バリデーション実装
  - location_id, catalog_id, order_date, order_time, quantity の必須バリデーション
  - quantity > 0 のバリデーション
  - _Requirements: 5.1, 5.2_

- [ ] 12.3 AdditionalOrder インデックス作成
  - idx_additional_orders_location（INDEX: location_id）
  - _Requirements: 5.4_

- [ ] 12.4 AdditionalOrder after_create コールバック実装
  - 在庫数加算ロジック（DailyInventory#increment_stock 呼び出し）
  - トランザクション管理
  - _Requirements: 5.2_

### Phase 10: Analytics & Reports Domain

- [ ] 13. Sales::AnalysisCalculator（販売分析 PORO）実装
- [ ] 13.1 (P) Sales::AnalysisCalculator クラス作成
  - app/models/sales ディレクトリ内に AnalysisCalculator クラス作成
  - 販売データ集計メソッドの基本構造
  - _Requirements: 6.1_

- [ ] 13.2 (P) 単純移動平均（SMA）計算実装
  - calculate_sma メソッド（過去 N 日間の平均販売数を計算）
  - 日付範囲、商品 ID、販売先 ID をパラメータとして受け取る
  - _Requirements: 6.2, 6.3_

- [ ] 13.3 (P) 追加発注予測実装
  - predict_additional_order メソッド（SMA ベースで追加発注数を予測）
  - 在庫残数と予測販売数の比較
  - _Requirements: 6.4, 6.5_

- [ ] 14. Reports::Generator（レポート生成 PORO）実装
- [ ] 14.1 (P) Reports::Generator クラス作成
  - app/models/reports ディレクトリ作成
  - Generator クラスの基本構造
  - _Requirements: 7.1_

- [ ] 14.2 (P) 日次レポート生成実装
  - generate_daily_report メソッド（日別の販売実績、在庫状況、追加発注履歴）
  - 販売先別、商品別の集計
  - _Requirements: 7.2, 7.3_

- [ ] 14.3 (P) 期間レポート生成実装
  - generate_period_report メソッド（期間別の販売実績、売上推移、人気商品ランキング）
  - 日付範囲、販売先、商品カテゴリでフィルタリング
  - _Requirements: 7.4, 7.5_

### Phase 11: Backend Controllers & Routes

- [ ] 15. Admin 用コントローラー実装
- [ ] 15.1 (P) LocationsController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - destroy アクションで deactivate 呼び出し（status = inactive）
  - フラッシュメッセージ表示
  - _Requirements: 16.1, 16.2, 16.3, 16.4_

- [ ] 15.2 (P) CatalogsController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - destroy アクションで CatalogDiscontinuation 作成
  - CatalogPrice の nested attributes 対応
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 15.3 (P) DiscountsController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - Coupon の nested attributes 対応
  - 有効期限の設定
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 15.4 (P) DailyInventoriesController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - 販売先別フィルタリング機能
  - 在庫一覧表示（location_id, catalog_id, inventory_date でグループ化）
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 2.6_

- [ ] 15.5 (P) AdminEmployeesController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - 従業員一覧表示
  - _Requirements: 9.5, 9.6, 9.7, 9.8_

- [ ] 16. POS 用コントローラー実装
- [ ] 16.1 SalesController 実装（DailyInventory, Sale, SaleItem, SaleDiscount, Sales::PriceCalculator 依存）
  - new アクション（販売先選択、在庫確認）
  - create アクション（販売記録作成、在庫減算、割引適用）
  - void アクション（販売取消、返品・返金処理）
  - トランザクション管理
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 15.1, 15.2, 15.8_

- [ ] 16.2 AdditionalOrdersController 実装
  - create アクション（追加発注記録、在庫加算）
  - index アクション（追加発注履歴表示）
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 17. ダッシュボード・レポート用コントローラー実装
- [ ] 17.1 (P) DashboardController 実装
  - index アクション（販売実績サマリー、在庫状況、追加発注履歴）
  - JSON エンドポイント（グラフ用データ提供）
  - _Requirements: 7.1, 7.2, 8.1, 8.2_

- [ ] 17.2 (P) AnalyticsController 実装
  - predict_additional_order アクション（Sales::AnalysisCalculator 呼び出し）
  - calculate_sma アクション
  - JSON レスポンス
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 18. ルーティング設定
- [ ] 18.1 config/routes.rb 設定
  - Admin 用リソースルーティング（locations, catalogs, discounts, daily_inventories, employees）
  - POS 用リソースルーティング（sales, additional_orders）
  - ダッシュボード・レポート用ルーティング（dashboard, analytics）
  - 認証用ルーティング（Rodauth）
  - _Requirements: 9.1, 9.2_

### Phase 12: Frontend - Admin Views

- [ ] 19. Location 管理画面実装
- [ ] 19.1 (P) Location 一覧・フォーム画面
  - locations/index.html.erb（販売先一覧、active/inactive フィルタ）
  - locations/new.html.erb, locations/edit.html.erb（販売先登録・編集フォーム）
  - Tailwind CSS でスタイリング
  - _Requirements: 16.1, 16.2, 16.4_

- [ ] 19.2 (P) Location 削除確認モーダル
  - 削除確認ダイアログ（Turbo Frame）
  - deactivate アクション呼び出し
  - _Requirements: 16.3_

- [ ] 20. Catalog 管理画面実装
- [ ] 20.1 (P) Catalog 一覧・フォーム画面
  - catalogs/index.html.erb（商品一覧、カテゴリフィルタ）
  - catalogs/new.html.erb, catalogs/edit.html.erb（商品登録・編集フォーム）
  - CatalogPrice の nested form（kind: regular/bundle）
  - _Requirements: 1.1, 1.2, 1.4, 14.1, 14.2_

- [ ] 20.2 (P) Catalog 削除確認モーダル
  - 削除確認ダイアログ（Turbo Frame）
  - CatalogDiscontinuation 作成
  - _Requirements: 1.3_

- [ ] 21. Discount 管理画面実装
- [ ] 21.1 (P) Discount 一覧・フォーム画面
  - discounts/index.html.erb（割引一覧、有効期限フィルタ）
  - discounts/new.html.erb, discounts/edit.html.erb（割引登録・編集フォーム）
  - Coupon の nested form（amount_per_unit, max_per_bento_quantity）
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 22. DailyInventory 管理画面実装
- [ ] 22.1 (P) DailyInventory 一覧・フォーム画面
  - daily_inventories/index.html.erb（在庫一覧、販売先別フィルタ）
  - daily_inventories/new.html.erb, daily_inventories/edit.html.erb（在庫登録・編集フォーム）
  - 販売先・日付・商品を選択するフォーム
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 2.6_

- [ ] 23. Employee 管理画面実装
- [ ] 23.1 (P) Employee 一覧・フォーム画面
  - employees/index.html.erb（従業員一覧）
  - employees/new.html.erb, employees/edit.html.erb（従業員登録・編集フォーム）
  - _Requirements: 9.5, 9.6, 9.7, 9.8_

### Phase 13: Frontend - POS Views

- [ ] 24. 販売（POS）画面実装
- [ ] 24.1 販売先選択画面
  - sales/new.html.erb（販売先選択フォーム）
  - active な Location のみ表示
  - Turbo Frame で在庫情報を動的読み込み
  - _Requirements: 3.8, 4.1_

- [ ] 24.2 商品選択・カート画面
  - 在庫がある商品のみ選択可能
  - 商品選択時に単価・数量入力
  - カート内の商品一覧表示（unit_price, quantity, line_total）
  - クーポン枚数入力フォーム
  - _Requirements: 3.1, 3.2, 3.5, 3.6, 13.7_

- [ ] 24.3 価格内訳表示
  - 小計（total_amount）表示
  - 適用された価格ルール表示（セット価格）
  - 適用された割引表示（クーポン）
  - 合計金額（final_amount）表示
  - _Requirements: 3.2, 13.8, 14.7_

- [ ] 24.4 販売確定・エラーハンドリング
  - 顧客区分（staff / citizen）選択
  - 販売確定ボタン
  - 在庫不足時のエラーメッセージ表示
  - 販売完了後のリダイレクト
  - _Requirements: 3.3, 3.4, 3.7_

- [ ] 25. リアルタイム在庫確認画面実装
- [ ] 25.1 在庫表示画面
  - inventories/show.html.erb（販売先ごとの現在在庫数表示）
  - 商品別に在庫数を表示
  - 在庫ゼロの商品を視覚的に識別（色変更）
  - Turbo Streams でリアルタイム更新
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 26. 追加発注画面実装
- [ ] 26.1 (P) 追加発注フォーム画面
  - additional_orders/new.html.erb（販売先、商品、数量、発注時刻入力フォーム）
  - 追加発注履歴一覧表示
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 27. 返品・返金画面実装
- [ ] 27.1 返品フォーム画面
  - sales/void.html.erb（元の Sale を選択、返品商品を選択）
  - 返品理由入力フォーム
  - 返金額の計算・表示
  - _Requirements: 15.1, 15.2, 15.3, 15.6, 15.12_

- [ ] 27.2 返金処理確認画面
  - 元の販売内容表示（商品、数量、金額）
  - 新規販売内容表示（返品分を除いた商品、再計算後の金額）
  - 返金額表示（差額）
  - 返金確定ボタン
  - _Requirements: 15.4, 15.5, 15.6, 15.7, 15.10, 15.11_

### Phase 14: Frontend - Dashboard & Reports

- [ ] 28. ダッシュボード画面実装
- [ ] 28.1 (P) ダッシュボード画面
  - dashboard/index.html.erb（販売実績サマリー、在庫状況、追加発注履歴）
  - 日別、期間別の販売実績表示
  - 人気商品ランキング表示
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 28.2 (P) グラフ表示（Chartkick + Chart.js）
  - 売上推移グラフ（折れ線グラフ）
  - 商品別販売数グラフ（棒グラフ）
  - 販売先別売上グラフ（円グラフ）
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

### Phase 15: Frontend - Stimulus Controllers

- [ ] 29. POS 用 Stimulus コントローラー実装
- [ ] 29.1 pos_controller.js 実装
  - 商品選択時のカート更新ロジック
  - クーポン枚数入力時の価格再計算
  - 価格内訳の動的表示
  - 在庫確認 API 呼び出し
  - _Requirements: 3.1, 3.2, 3.5, 3.6, 13.7, 14.7_

- [ ] 29.2 inventory_controller.js 実装
  - リアルタイム在庫更新（Turbo Streams）
  - 在庫ゼロの視覚的識別
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 30. オフライン同期用 Stimulus コントローラー実装
- [ ] 30.1 offline_sync_controller.js 実装
  - LocalStorage への販売データ保存
  - オンライン復帰時の同期処理
  - 同期ステータス表示
  - _Requirements: 11.1, 11.2, 11.3_

- [ ] 30.2 Service Worker 実装
  - オフライン時の静的アセットキャッシュ
  - オンライン・オフライン状態の検出
  - _Requirements: 11.4, 11.5_

### Phase 16: Backend - Offline Sync

- [ ] 31. Sales::OfflineSynchronizer（オフライン同期 PORO）実装
- [ ] 31.1 Sales::OfflineSynchronizer クラス作成
  - app/models/sales ディレクトリ内に OfflineSynchronizer クラス作成
  - LocalStorage からのデータ受信
  - _Requirements: 11.1_

- [ ] 31.2 同期処理ロジック実装
  - オフライン販売データの検証
  - 在庫確認・重複チェック
  - Sale, SaleItem, SaleDiscount の一括作成
  - トランザクション管理
  - エラーハンドリング
  - _Requirements: 11.2, 11.3_

- [ ] 31.3 同期 API エンドポイント実装
  - POST /api/sales/sync
  - JSON レスポンス（成功・失敗ステータス）
  - _Requirements: 11.1, 11.2_

### Phase 17: Performance & Caching

- [ ] 32. Solid Cache 設定
- [ ] 32.1 (P) キャッシュ戦略実装
  - Catalog, CatalogPrice, Discount のキャッシュ
  - DailyInventory のキャッシュ（販売先・日付ごと）
  - キャッシュ無効化ロジック（商品更新、在庫更新時）
  - _Requirements: 12.3_

- [ ] 32.2 (P) インデックス最適化確認
  - 全インデックスの作成確認
  - スロークエリの特定
  - EXPLAIN ANALYZE での検証
  - _Requirements: 12.4_

### Phase 18: Responsive Design

- [ ] 33. レスポンシブデザイン実装
- [ ] 33.1 スマホ最適化（POS 画面）
  - Tailwind CSS responsive classes 適用
  - タッチ操作対応
  - フォントサイズ調整
  - _Requirements: 3.5, 10.1, 10.2_

- [ ] 33.2 PC 最適化（Admin 画面）
  - 管理画面のレイアウト調整
  - テーブル表示の最適化
  - _Requirements: 10.3, 10.4_

- [ ] 33.3 タブレット対応
  - 中間サイズのレイアウト調整
  - _Requirements: 10.5_

### Phase 19: Testing

- [ ] 34. モデルテスト実装
- [ ]* 34.1 Location モデルテスト
  - バリデーションテスト（name 必須、ユニーク性）
  - status enum テスト
  - deactivate/activate メソッドテスト
  - _Requirements: 16.1, 16.2, 16.3_

- [ ]* 34.2 Catalog モデルテスト
  - バリデーションテスト（name ユニーク、category 必須）
  - CatalogPrice, CatalogPricingRule, CatalogDiscontinuation の関連テスト
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 34.3 Discount モデルテスト
  - delegated_type パターンテスト
  - Coupon の applicable? メソッドテスト
  - calculate_discount メソッドテスト
  - _Requirements: 13.1, 13.4, 13.5_

- [ ]* 34.4 DailyInventory モデルテスト
  - バリデーションテスト（stock >= 0）
  - ユニーク制約テスト（location_id, catalog_id, inventory_date）
  - decrement_stock/increment_stock メソッドテスト
  - optimistic locking テスト
  - _Requirements: 2.1, 2.2, 2.4, 12.1, 12.2_

- [ ]* 34.5 Sale モデルテスト
  - バリデーションテスト（location_id 必須、status enum）
  - void! メソッドテスト
  - corrected_from_sale_id の関連テスト
  - _Requirements: 3.3, 15.1, 15.2_

- [ ]* 34.6 SaleItem モデルテスト
  - バリデーションテスト（quantity > 0, unit_price >= 0）
  - line_total 計算テスト
  - after_create コールバックテスト（在庫減算）
  - _Requirements: 3.1, 3.2, 3.4_

- [ ]* 34.7 Refund モデルテスト
  - バリデーションテスト（amount >= 0）
  - original_sale, corrected_sale の関連テスト
  - _Requirements: 15.10_

- [ ]* 34.8 AdditionalOrder モデルテスト
  - バリデーションテスト（quantity > 0）
  - after_create コールバックテスト（在庫加算）
  - _Requirements: 5.1, 5.2_

- [ ] 35. PORO テスト実装
- [ ]* 35.1 Sales::PriceCalculator テスト
  - 価格ルール適用テスト（セット価格）
  - 割引適用テスト（クーポン）
  - calculate メソッド統合テスト
  - _Requirements: 3.1, 3.2, 13.8, 14.7_

- [ ]* 35.2 Sales::AnalysisCalculator テスト
  - calculate_sma メソッドテスト
  - predict_additional_order メソッドテスト
  - _Requirements: 6.2, 6.4_

- [ ]* 35.3 Reports::Generator テスト
  - generate_daily_report メソッドテスト
  - generate_period_report メソッドテスト
  - _Requirements: 7.2, 7.4_

- [ ]* 35.4 Sales::OfflineSynchronizer テスト
  - 同期処理ロジックテスト
  - 重複チェックテスト
  - エラーハンドリングテスト
  - _Requirements: 11.2, 11.3_

- [ ] 36. コントローラーテスト実装
- [ ]* 36.1 LocationsController テスト
  - CRUD アクションテスト
  - deactivate アクションテスト
  - _Requirements: 16.1, 16.2, 16.3_

- [ ]* 36.2 CatalogsController テスト
  - CRUD アクションテスト
  - CatalogDiscontinuation 作成テスト
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 36.3 DiscountsController テスト
  - CRUD アクションテスト
  - _Requirements: 13.1, 13.2_

- [ ]* 36.4 DailyInventoriesController テスト
  - CRUD アクションテスト
  - 販売先別フィルタリングテスト
  - _Requirements: 2.1, 2.5, 2.6_

- [ ]* 36.5 SalesController テスト
  - create アクションテスト（販売記録、在庫減算、割引適用）
  - void アクションテスト（返品・返金処理）
  - トランザクションテスト
  - _Requirements: 3.1, 3.3, 3.4, 15.1, 15.2_

- [ ]* 36.6 AdditionalOrdersController テスト
  - create アクションテスト（追加発注記録、在庫加算）
  - _Requirements: 5.1, 5.2_

- [ ]* 36.7 DashboardController テスト
  - index アクションテスト
  - JSON エンドポイントテスト
  - _Requirements: 7.1, 8.1_

- [ ] 37. 統合テスト実装
- [ ]* 37.1 販売フロー統合テスト
  - 販売先選択 → 商品選択 → 価格計算 → 販売確定 → 在庫減算
  - クーポン適用 → 価格再計算
  - セット価格適用 → 価格再計算
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 13.8, 14.7_

- [ ]* 37.2 返品・返金フロー統合テスト
  - 販売取消 → 新規販売作成 → 返金額計算 → 在庫復元
  - 全商品返品 → 全額返金
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.9, 15.11_

- [ ]* 37.3 追加発注フロー統合テスト
  - 追加発注記録 → 在庫加算
  - _Requirements: 5.1, 5.2_

- [ ]* 37.4 オフライン同期フロー統合テスト
  - オフライン販売データ保存 → オンライン復帰 → 同期処理
  - _Requirements: 11.1, 11.2, 11.3_

- [ ] 38. E2E テスト実装（System tests）
- [ ]* 38.1 POS 画面 E2E テスト
  - 販売先選択 → 商品選択 → クーポン入力 → 販売確定
  - スマホサイズでの操作確認
  - _Requirements: 3.1, 3.2, 3.3, 3.5_

- [ ]* 38.2 Admin 画面 E2E テスト
  - 商品登録 → 在庫登録 → 販売実績確認
  - _Requirements: 1.1, 2.1, 7.1_

### Phase 20: Integration & Final Checks

- [ ] 39. システム統合
- [ ] 39.1 全機能統合確認
  - Location, Catalog, Discount, DailyInventory, Sale, SaleItem, SaleDiscount, Refund, AdditionalOrder の連携確認
  - Sales::PriceCalculator の統合確認
  - Sales::OfflineSynchronizer の統合確認
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 13.8, 14.7, 15.1, 15.2_

- [ ] 39.2 データ整合性確認
  - 在庫数の整合性（販売、返品、追加発注）
  - 販売金額の整合性（価格ルール、割引）
  - 返金額の整合性
  - _Requirements: 12.4, 12.5_

- [ ] 39.3 パフォーマンス確認
  - スロークエリの特定と最適化
  - キャッシュの有効性確認
  - N+1 クエリの検出と修正
  - _Requirements: 12.3, 12.4_

- [ ] 40. セキュリティ確認
- [ ] 40.1 (P) 認可チェック
  - Admin のみ管理画面アクセス可能
  - Employee は販売画面のみアクセス可能
  - _Requirements: 9.9, 9.10_

- [ ] 40.2 (P) CSRF 保護確認
  - form_with での CSRF トークン確認
  - _Requirements: 9.1_

- [ ] 40.3 (P) SQL インジェクション対策確認
  - ActiveRecord の prepared statement 確認
  - _Requirements: 12.1_

---

## Requirements Coverage

全 16 の要件がカバーされています:

- **Requirement 1**: 弁当商品マスタ管理 → Tasks 4, 15.2, 20, 34.2, 36.2, 38.2
- **Requirement 2**: 販売先ごとの在庫登録 → Tasks 6, 15.4, 22, 34.4, 36.4, 38.2
- **Requirement 3**: 販売記録（POS機能） → Tasks 7, 8, 16.1, 24, 29.1, 33.1, 34.5, 34.6, 36.5, 37.1, 38.1
- **Requirement 4**: リアルタイム在庫確認 → Tasks 25, 29.2
- **Requirement 5**: 追加発注記録 → Tasks 12, 16.2, 26, 34.8, 36.6, 37.3
- **Requirement 6**: 販売データ分析 → Tasks 13, 17.2, 35.2
- **Requirement 7**: 販売実績レポート → Tasks 14, 17.1, 28.1, 35.3, 36.7, 38.2
- **Requirement 8**: 販売データ可視化 → Tasks 17.1, 28.2
- **Requirement 9**: 認証と従業員管理 → Tasks 2, 15.5, 18.1, 23, 40
- **Requirement 10**: レスポンシブデザイン → Tasks 33
- **Requirement 11**: オフライン対応 → Tasks 30, 31, 37.4
- **Requirement 12**: データ整合性とパフォーマンス → Tasks 1, 6, 32, 39.2, 39.3, 40
- **Requirement 13**: 割引（クーポン）管理と適用 → Tasks 5, 9, 10.3, 15.3, 21, 24.2, 24.3, 34.3, 36.3, 37.1
- **Requirement 14**: サイドメニュー（サラダ）の条件付き価格設定 → Tasks 4.2, 4.3, 10.2, 20.1, 24.3, 37.1
- **Requirement 15**: 返品・返金処理（取消・再販売・差額返金） → Tasks 7, 11, 16.1, 27, 34.7, 36.5, 37.2
- **Requirement 16**: 販売先（ロケーション）管理 → Tasks 3, 6.1, 7.1, 12.1, 15.1, 19, 24.1, 34.1, 36.1

---

## Task Summary

- **総タスク数**: 40 major tasks, 127 sub-tasks
- **並列実行可能タスク**: 45 tasks marked with `(P)`
- **オプショナルテストタスク**: 39 tasks marked with `*` (deferrable post-MVP)
- **平均タスクサイズ**: 1-3 hours per sub-task
- **全要件カバレッジ**: 16/16 requirements (100%)

---

**次のステップ**: タスクを確認後、`/kiro:spec-impl sales-tracking-pos 1.1` で実装を開始してください。
