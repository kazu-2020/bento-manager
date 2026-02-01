# Implementation Plan

## Project: sales-tracking-pos

**Feature Name**: 販売記録・追加発注・データ分析システム（POS + Analytics）
**Language**: ja
**Phase**: tasks-generated
**Generated**: 2026-01-04
**Updated**: 2026-02-01

---

## Task List

### Phase 1: Foundation & Database Setup

- [x] 1. データベース基盤構築
- [x] 1.1 マルチデータベーススキーマ設定
  - primary database の設定確認
  - schema.rb のベースライン作成
  - _Requirements: 11.1_

- [x] 1.2 (P) マイグレーション基盤準備
  - マイグレーション用のディレクトリ構造確認
  - タイムスタンプ付きマイグレーションファイル命名規則の確認
  - _Requirements: 11.1_

### Phase 2: Authentication

- [x] 2. Rodauth 認証システム構築
- [x] 2.1 Employee 認証セットアップ
  - Employee アカウント設定（username、パスワードハッシュ）
  - ログイン/ログアウト機能の実装
  - セッション管理の設定
  - Rodauth 設定: `login_column :username`
  - username カラムに COLLATE NOCASE を設定（大文字小文字を区別しない一意制約）
  - Employee の登録・編集・削除は Rails console で行う（管理画面は不要）
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9_

### Phase 3: Core Domain Models - Location & Catalog

- [x] 3. Location（販売先）ドメイン実装
- [x] 3.1 (P) Location モデル作成
  - Location テーブルマイグレーション（id, name, status, created_at, updated_at）
  - status enum（active / inactive）の実装
  - default_scope で active のみ取得
  - deactivate/activate メソッド実装
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7_

- [x] 3.2 (P) Location バリデーション実装
  - name の必須バリデーション
  - name の一意性バリデーション
  - _Requirements: 15.6_

- [x] 3.3 (P) Location インデックス作成
  - idx_locations_name インデックス追加
  - _Requirements: 15.4_

- [x] 4. Catalog（商品カタログ）ドメイン実装
- [x] 4.1 (P) Catalog モデル作成
  - Catalog テーブルマイグレーション（id, name, category, description）
  - category enum（bento / side_menu）の実装
  - _Requirements: 1.1, 1.2, 1.4_

- [x] 4.2 (P) CatalogPrice モデル作成
  - CatalogPrice テーブルマイグレーション（id, catalog_id, kind, price, effective_from, effective_until）
  - kind enum（regular / bundle）の実装
  - effective_from/effective_until による価格履歴管理
  - _Requirements: 1.1, 1.5, 13.1, 13.2_

- [x] 4.3 (P) CatalogPricingRule モデル作成
  - CatalogPricingRule テーブルマイグレーション（id, target_catalog_id, price_kind, trigger_category, max_per_trigger, valid_from, valid_until）
  - セット価格適用ルールのロジック実装
  - applicable? メソッド実装
  - _Requirements: 13.3, 13.4, 13.5, 13.6_

- [x] 4.4 (P) CatalogDiscontinuation モデル作成
  - CatalogDiscontinuation テーブルマイグレーション（id, catalog_id, discontinued_at, reason）
  - catalog_id のユニーク制約
  - _Requirements: 1.3_

- [x] 4.5 (P) Catalog バリデーション実装
  - name のユニーク制約
  - category の必須バリデーション
  - price > 0 のバリデーション
  - _Requirements: 1.1, 1.4, 1.5_

- [x] 4.6 (P) Catalog インデックス作成
  - idx_catalogs_name インデックス追加
  - idx_catalog_prices_catalog_kind インデックス追加
  - idx_catalog_pricing_rules_target インデックス追加
  - _Requirements: 1.4_

### Phase 4: Discount Domain

- [x] 5. Discount（割引）ドメイン実装
- [x] 5.1 (P) Discount 抽象モデル作成
  - Discount テーブルマイグレーション（id, discountable_type, discountable_id, name, valid_from, valid_until）
  - delegated_type パターン実装
  - applicable? メソッドの委譲
  - calculate_discount メソッド実装
  - _Requirements: 12.1, 12.2, 12.3_

- [x] 5.2 (P) Coupon モデル作成
  - Coupon テーブルマイグレーション（id, description, amount_per_unit, max_per_bento_quantity）
  - applicable? メソッド実装（弁当が含まれるか判定）
  - max_applicable_quantity メソッド実装
  - calculate_discount メソッド実装
  - _Requirements: 12.4, 12.5, 12.6, 12.7_

- [x] 5.3 (P) Discount バリデーション実装
  - name, valid_from, valid_until の必須バリデーション
  - amount_per_unit > 0 のバリデーション
  - max_per_bento_quantity >= 0 のバリデーション
  - _Requirements: 12.1, 12.2_

- [x] 5.4 (P) Discount インデックス作成
  - idx_discounts_name_valid_from インデックス追加
  - _Requirements: 12.1_

### Phase 5: Inventory Domain

- [x] 6. DailyInventory（日次在庫）ドメイン実装
- [x] 6.1 DailyInventory モデル作成（Location, Catalog 依存）
  - DailyInventory テーブルマイグレーション（id, location_id, catalog_id, inventory_date, stock, reserved_stock, lock_version）
  - location_id, catalog_id の外部キー制約
  - (location_id, catalog_id, inventory_date) のユニーク制約
  - optimistic locking（lock_version）の設定
  - _Requirements: 2.1, 2.2, 2.4, 11.1, 11.2, 15.1_

- [x] 6.2 DailyInventory バリデーション実装
  - stock >= 0, reserved_stock >= 0 のバリデーション
  - available_stock = stock - reserved_stock >= 0 の検証
  - location_id, catalog_id, inventory_date の必須バリデーション
  - _Requirements: 2.4, 11.4_

- [x] 6.3 DailyInventory インデックス作成
  - idx_daily_inventories_location_catalog_date（UNIQUE: location_id, catalog_id, inventory_date）
  - idx_daily_inventories_location（INDEX: location_id）
  - _Requirements: 2.2_

- [x] 6.4 DailyInventory 在庫操作メソッド実装
  - decrement_stock メソッド（販売時の在庫減算）
  - increment_stock メソッド（返品時の在庫復元）
  - トランザクション管理
  - _Requirements: 3.4, 14.9, 11.5_

### Phase 6: Sales Domain - Core Models

- [x] 7. Sale（販売記録）ドメイン実装
- [x] 7.1 Sale モデル作成（Location, Employee 依存）
  - Sale テーブルマイグレーション（id, location_id, sale_datetime, customer_type, total_amount, final_amount, employee_id, status, voided_at, voided_by_employee_id, void_reason, corrected_from_sale_id）
  - location_id, employee_id の外部キー制約
  - status enum（completed / voided）の実装
  - customer_type enum（staff / citizen）の実装
  - _Requirements: 3.3, 3.5, 14.1, 14.2, 14.8, 15.1_

- [x] 7.2 Sale バリデーション実装
  - location_id, sale_datetime, customer_type の必須バリデーション
  - total_amount >= 0, final_amount >= 0 のバリデーション
  - status が voided の場合、voided_at, voided_by_employee_id, void_reason が必須
  - _Requirements: 3.3, 14.8_

- [x] 7.3 Sale インデックス作成
  - idx_sales_location_datetime（INDEX: location_id, sale_datetime）
  - idx_sales_datetime（INDEX: sale_datetime）
  - idx_sales_status（INDEX: status）
  - _Requirements: 3.3, 7.1, 14.1_

- [x] 7.4 Sale mark_as_voided! メソッド実装
  - mark_as_voided! メソッド（status を voided に変更、voided_at, voided_by_employee_id, void_reason を記録）
  - voided? メソッド
  - 返品フロー全体は Sales::Refunder PORO が担当
  - _Requirements: 14.1, 14.2, 14.8_

- [x] 8. SaleItem（販売明細）モデル実装
- [x] 8.1 SaleItem モデル作成（Sale, Catalog, CatalogPrice 依存）
  - SaleItem テーブルマイグレーション（id, sale_id, catalog_id, catalog_price_id, quantity, unit_price, line_total, sold_at）
  - sale_id, catalog_id, catalog_price_id の外部キー制約
  - _Requirements: 3.1, 3.2, 13.7_

- [x] 8.2 SaleItem バリデーション実装
  - quantity > 0 のバリデーション
  - unit_price >= 0 のバリデーション
  - line_total = unit_price × quantity の整合性検証
  - _Requirements: 3.1, 3.2_

- [x] 8.3 SaleItem インデックス作成
  - idx_sale_items_sale_id（INDEX: sale_id）
  - idx_sale_items_catalog_id（INDEX: catalog_id）
  - idx_sale_items_catalog_price_id（INDEX: catalog_price_id）
  - idx_sale_items_sale_catalog（INDEX: sale_id, catalog_id）
  - _Requirements: 3.1_

- [x] 8.4 SaleItem 純粋データモデル実装
  - before_validation での line_total 自動計算（unit_price × quantity）
  - 在庫減算は Sales::Recorder PORO で明示的に実行（コールバックなし）
  - _Requirements: 3.4, 3.7_

- [x] 9. SaleDiscount（販売・割引中間テーブル）モデル実装
- [x] 9.1 (P) SaleDiscount モデル作成
  - SaleDiscount テーブルマイグレーション（id, sale_id, discount_id, discount_amount）
  - sale_id, discount_id の外部キー制約
  - (sale_id, discount_id) のユニーク制約
  - _Requirements: 12.8, 12.9_

- [x] 9.2 (P) SaleDiscount バリデーション実装
  - sale_id, discount_id, discount_amount の必須バリデーション
  - discount_amount >= 0 のバリデーション
  - 同じ割引の重複適用防止
  - _Requirements: 12.8_

- [x] 9.3 (P) SaleDiscount インデックス作成
  - idx_sale_discounts_unique（UNIQUE: sale_id, discount_id）
  - _Requirements: 12.8_

### Phase 7: Sales Domain - Business Logic POROs

- [x] 10. Sales::PriceCalculator（価格計算 PORO）実装
- [x] 10.1 Sales::PriceCalculator クラス作成（Catalog, CatalogPrice, CatalogPricingRule, Discount 依存）
  - PriceCalculator クラスの基本構造
  - initialize メソッド（cart_items, discount_ids を受け取る）
  - _Requirements: 3.1, 3.2, 12.1, 13.1_

- [x] 10.2 価格ルール適用ロジック実装
  - apply_pricing_rules メソッド（CatalogPricingRule#applicable? を判定）
  - セット価格適用条件の判定（弁当1個につきサラダ1個まで）
  - 単品価格とセット価格の使い分け
  - _Requirements: 13.3, 13.4, 13.5, 13.6_

- [x] 10.3 割引適用ロジック実装
  - apply_discounts メソッド（Discount#applicable? を判定）
  - クーポン枚数の計算（弁当の合計個数（quantity の合計）× max_per_bento_quantity）
  - 例: 日替わりA 3個 + 日替わりB 2個 = 弁当5個 → クーポン最大5枚適用可能
  - 複数割引の合算
  - _Requirements: 12.2, 12.4, 12.5, 12.6, 12.7, 12.8_

- [x] 10.4 calculate メソッド実装
  - Step 1: 価格存在検証（determine_required_price_kinds → PriceValidator で検証）
  - Step 2: 価格ルール適用（CatalogPricingRule）
  - Step 3: 小計計算（unit_price × quantity）
  - Step 4: 割引適用（Discount#calculate_discount）
  - Step 5: 最終金額計算（total_amount - total_discount_amount）
  - 価格内訳の返却（item_details, discount_details, total_amount, final_amount）
  - _Requirements: 3.1, 3.2, 12.8, 13.7, 16.1, 16.2, 16.3, 16.4_

- [x] 11. Catalogs::PriceValidator（価格存在検証 PORO）実装
- [x] 11.1 Catalogs::PriceValidator クラス作成
  - PriceValidator クラスの基本構造（薄い部品として設計 — 決定18）
  - price_exists? インスタンスメソッド（catalog, kind の2引数、at はコンストラクタで指定）
  - MissingPriceError カスタム例外クラス（catalog_name, price_kind 属性を保持）
  - _Requirements: 16.1, 16.2_

- [x] 11.2 find_price / find_price! メソッド実装
  - find_price: 価格取得（存在しない場合は nil）
  - find_price!: 価格取得（存在しない場合は MissingPriceError）
  - _Requirements: 16.2, 16.3_

- [x] 11.3 catalogs_with_missing_prices メソッド実装
  - 管理画面用: 価格設定に不備がある全商品を返す
  - 有効な価格ルールが参照する価格種別に対応する CatalogPrice が存在しない商品を検出
  - 戻り値: 商品と不足価格種別のリスト
  - _Requirements: 17.1, 17.2, 17.3, 17.6_

- [x] 11.4 Sales::PriceCalculator への価格存在検証統合（決定18）
  - PriceCalculator.calculate 内で価格ルール適用前に検証を実行
  - 「何の kind が必要か」は PriceCalculator#determine_required_price_kinds が決定
  - PriceValidator#price_exists? を呼び出して価格存在を検証
  - 価格不足時は MissingPriceError を発生（商品名と価格種別を含む）
  - _Requirements: 16.1, 16.2, 16.3, 16.4_

- [x] 11.5 Sales::Recorder への統合（決定18）
  - Sales::Recorder は PriceCalculator.calculate を呼び出し
  - PriceCalculator 内で価格存在検証が実行される（Recorder は直接呼び出さない）
  - MissingPriceError 発生時はエラーログを記録
  - トランザクション開始前に検証が完了するため、在庫減算なし
  - _Requirements: 16.5, 16.6, 16.7_

- [x] 12. Catalog::PricingRuleCreator（価格ルール作成 PORO）実装
- [x] 12.1 Catalog::PricingRuleCreator クラス作成
  - PricingRuleCreator クラスの基本構造
  - MissingPriceError カスタム例外クラス
  - _Requirements: 18.1, 18.3, 18.4_

- [x] 12.2 create メソッド実装
  - CatalogPricingRule のインスタンス作成
  - 今日時点で有効化される場合は価格存在検証を実行
  - 検証成功時のみ save! を実行
  - _Requirements: 18.1, 18.5, 18.6_

- [x] 12.3 update メソッド実装
  - 既存 CatalogPricingRule の属性更新
  - 有効化（active）される場合は価格存在検証を実行
  - 無効化（inactive）の場合は検証をスキップ
  - _Requirements: 18.2, 18.5, 18.6, 18.7_

- [x] 12.4 validate_price_existence! プライベートメソッド実装
  - 参照する価格種別（kind）に対応する CatalogPrice の存在確認
  - 今日時点（Date.current）で有効な価格のみを検証対象
  - 不足時は MissingPriceError を発生
  - _Requirements: 18.3, 18.4, 18.5_

### Phase 8: Sales::Refunder & Refund Domain

- [x] 13. Sales::Refunder（返品・返金処理 PORO）実装
- [x] 13.1 Sales::Refunder クラス作成
  - 返品・返金処理を一括で行う PORO の基本構造
  - AlreadyVoidedError カスタム例外クラス（既に取消済みの Sale を再取消しようとした場合）
  - Sales::Recorder と対称的な設計（販売記録 ↔ 返品記録）
  - _Requirements: 14.1, 14.8_

- [x] 13.2 refund メソッド — 元 Sale の取消と在庫復元
  - 元 Sale が既に voided でないことを検証（AlreadyVoidedError）
  - トランザクション開始
  - Sale#mark_as_voided! を呼び出して元 Sale を取消状態に変更
  - 元 Sale の全 SaleItem 数量を DailyInventory.stock に加算して在庫復元（楽観的ロック）
  - _Requirements: 14.1, 14.2, 14.8, 14.9_

- [x] 13.3 refund メソッド — 残す商品での再販売作成
  - 残す商品がある場合、Sales::PriceCalculator で価格ルール・クーポンを再評価
  - 新規 Sale を作成（corrected_from_sale_id を設定）
  - 再評価された価格で SaleItem を作成し、在庫減算
  - 全商品返品時は新規 Sale を作成しない
  - _Requirements: 14.3, 14.4, 14.5, 14.6, 14.11_

- [x] 13.4 refund メソッド — 差額返金記録とエラーハンドリング
  - 差額（元 Sale.final_amount - 新 Sale.final_amount）を計算し Refund レコード作成
  - 全額返金時は corrected_sale_id を nil に設定
  - 返金理由の記録
  - トランザクション commit
  - StaleObjectError（楽観的ロック競合）の rescue と再試行促進
  - _Requirements: 14.5, 14.7, 14.9, 14.10, 14.12_

- [x] 14. Refund（返金記録）モデル実装
- [x] 14.1 Refund モデル作成（Sale, Employee 依存）
  - Refund テーブルマイグレーション（id, original_sale_id, corrected_sale_id, employee_id, refund_datetime, amount, reason）
  - original_sale_id, corrected_sale_id, employee_id の外部キー制約
  - _Requirements: 14.3, 14.7, 14.10, 14.12_

- [x] 14.2 Refund バリデーション実装
  - original_sale_id, refund_datetime, amount の必須バリデーション
  - amount >= 0 のバリデーション
  - _Requirements: 14.10_

- [x] 14.3 Refund インデックス作成
  - idx_refunds_original_sale（INDEX: original_sale_id）
  - idx_refunds_corrected_sale（INDEX: corrected_sale_id）
  - _Requirements: 14.3_

### Phase 9: Additional Order Domain

- [x] 15. AdditionalOrder（追加発注）ドメイン実装
- [x] 15.1 AdditionalOrder モデル作成（Location, Catalog, Employee 依存）
  - AdditionalOrder テーブルマイグレーション（id, location_id, catalog_id, order_date, order_time, quantity, employee_id）
  - location_id, catalog_id, employee_id の外部キー制約
  - _Requirements: 5.1, 5.2, 15.1_

- [x] 15.2 AdditionalOrder バリデーション実装
  - location_id, catalog_id, order_date, order_time, quantity の必須バリデーション
  - quantity > 0 のバリデーション
  - _Requirements: 5.1, 5.2_

- [x] 15.3 AdditionalOrder インデックス作成
  - idx_additional_orders_location（INDEX: location_id）
  - _Requirements: 5.4_

- [x] 15.4 AdditionalOrder after_create コールバック実装
  - 在庫数加算ロジック（DailyInventory#increment_stock 呼び出し）
  - トランザクション管理
  - _Requirements: 5.2_

### Phase 10: Analytics & Reports Domain

- [ ] 16. Sales::AnalysisCalculator（販売分析 PORO）実装
- [ ] 16.1 (P) Sales::AnalysisCalculator クラス作成
  - 販売データ集計メソッドの基本構造
  - _Requirements: 6.1_

- [ ] 16.2 (P) 単純移動平均（SMA）計算実装
  - calculate_sma メソッド（過去 N 日間の平均販売数を計算）
  - 日付範囲、商品 ID、販売先 ID をパラメータとして受け取る
  - _Requirements: 6.2, 6.3_

- [ ] 16.3 (P) 追加発注予測実装
  - predict_additional_order メソッド（SMA ベースで追加発注数を予測）
  - 在庫残数と予測販売数の比較
  - _Requirements: 6.4, 6.5_

- [ ] 17. Reports::Generator（レポート生成 PORO）実装
- [ ] 17.1 (P) Reports::Generator クラス作成
  - Generator クラスの基本構造
  - _Requirements: 7.1_

- [ ] 17.2 (P) 日次レポート生成実装
  - generate_daily_report メソッド（日別の販売実績、在庫状況、追加発注履歴）
  - 販売先別、商品別の集計
  - _Requirements: 7.2, 7.3_

- [ ] 17.3 (P) 期間レポート生成実装
  - generate_period_report メソッド（期間別の販売実績、売上推移、人気商品ランキング）
  - 日付範囲、販売先、商品カテゴリでフィルタリング
  - _Requirements: 7.4, 7.5_

### Phase 11: Backend Controllers & Routes

- [x] 18. コントローラー実装
- [x] 18.1 (P) LocationsController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - destroy アクションで deactivate 呼び出し（status = inactive）
  - フラッシュメッセージ表示
  - /locations パスで認証済み Employee がアクセス可能
  - _Requirements: 15.1, 15.2, 15.3, 15.4_

- [x] 18.2 (P) CatalogsController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - destroy アクションで CatalogDiscontinuation 作成
  - CatalogPrice の nested attributes 対応
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 18.3 (P) DiscountsController 実装
  - CRUD アクション（index, show, new, create, edit, update, destroy）
  - Coupon の nested attributes 対応
  - 有効期限の設定
  - _Requirements: 12.1, 12.2, 12.3_

- [x] 19. POS 用コントローラー実装
- [x] 19.1 SalesController 実装（DailyInventory, Sale, SaleItem, SaleDiscount, Sales::PriceCalculator, Sales::Refunder 依存）
  - new アクション（販売先選択、在庫確認）
  - create アクション（Sales::Recorder 呼び出し: 販売記録作成、在庫減算、割引適用）
  - void アクション（Sales::Refunder 呼び出し: 販売取消、在庫復元、再販売、返金記録）
  - トランザクション管理
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 14.1, 14.2, 14.8_

- [x] 19.2 AdditionalOrdersController 実装
  - create アクション（追加発注記録、在庫加算）
  - new アクション（追加発注フォーム + 在庫情報 + 履歴表示）
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 20. ダッシュボード・レポート用コントローラー実装
- [ ] 20.1 (P) DashboardController 実装
  - index アクション（販売実績サマリー、在庫状況、追加発注履歴）
  - JSON エンドポイント（グラフ用データ提供）
  - _Requirements: 7.1, 7.2, 8.1, 8.2_

- [ ] 20.2 (P) AnalyticsController 実装
  - predict_additional_order アクション（Sales::AnalysisCalculator 呼び出し）
  - calculate_sma アクション
  - JSON レスポンス
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 21. ルーティング設定
  - リソースルーティング（locations, catalogs, discounts, daily_inventories）
  - POS 用リソースルーティング（sales, additional_orders）
  - ダッシュボード・レポート用ルーティング（dashboard, analytics）
  - 認証用ルーティング（Rodauth）
  - _Requirements: 9.1, 9.2_

### Phase 12: Frontend - Admin Views

- [x] 22. Location 管理画面実装
- [x] 22.1 (P) Location 一覧・フォーム画面
  - 販売先一覧（ViewComponent で実装）
  - 新規作成: モーダル形式（Turbo Stream）
  - 編集: インライン編集（Turbo Frame）
  - Tailwind CSS + DaisyUI でスタイリング
  - _Requirements: 15.1, 15.2, 15.4_

- [x] 22.2 (P) Location 状態変更機能
  - 編集画面で status (active/inactive) を変更可能
  - status セレクトボックス実装
  - _Requirements: 15.3_

- [x] 23. Catalog 管理画面実装
- [x] 23.1 (P) Catalog 一覧・フォーム画面
  - 商品一覧（カテゴリタブ、ViewComponent で実装）
  - 商品登録フォーム（bento/side_menu 別フィールド）
  - 価格編集（履歴管理付き）
  - CatalogPrice の kind（regular / bundle）対応
  - _Requirements: 1.1, 1.2, 1.4, 13.1, 13.2_

- [x] 23.2 (P) Catalog 削除確認モーダル
  - 削除確認ダイアログ（Turbo Frame）
  - CatalogDiscontinuation 作成
  - _Requirements: 1.3_

- [x] 24. Discount 管理画面実装
- [x] 24.1 (P) Discount 一覧・フォーム画面
  - 割引一覧（有効期限フィルタ）
  - 割引登録・編集フォーム
  - Coupon の nested form（amount_per_unit, max_per_bento_quantity）
  - _Requirements: 12.1, 12.2, 12.3_

- [ ] 25. 管理画面での価格設定警告表示実装
- [ ] 25.1 (P) CatalogsController index アクション更新
  - Catalogs::PriceValidator#catalogs_with_missing_prices を呼び出し
  - 警告対象の商品リストをビューに渡す
  - _Requirements: 17.1, 17.2_

- [ ] 25.2 (P) 商品一覧画面に警告表示実装
  - 価格設定に不備がある商品を視覚的に警告表示（赤背景、アイコン）
  - 不足している価格種別（kind）を表示
  - 警告クリックで価格設定画面に遷移
  - _Requirements: 17.1, 17.3, 17.4_

- [ ] 25.3 (P) 警告セクション実装
  - 警告がある商品を一覧上部または別セクションにまとめて表示
  - 「すべての商品に価格が正しく設定されています」の正常状態表示
  - _Requirements: 17.5, 17.6_

### Phase 13: Frontend - POS Views

- [ ] 26. 販売（POS）画面実装
- [x] 26.1 販売先選択画面
  - 販売先選択フォーム
  - active な Location のみ表示
  - Turbo Frame で在庫情報を動的読み込み
  - _Requirements: 3.8, 4.1_

- [x] 26.2 商品選択・カート画面
  - 在庫がある商品のみ選択可能
  - 商品選択時に単価・数量入力
  - カート内の商品一覧表示（unit_price, quantity, line_total）
  - クーポン枚数入力フォーム
  - _Requirements: 3.1, 3.2, 3.5, 3.6, 12.7_

- [x] 26.3 価格内訳表示
  - 小計（total_amount）表示
  - 適用された価格ルール表示（セット価格）
  - 適用された割引表示（クーポン）
  - 合計金額（final_amount）表示
  - _Requirements: 3.2, 12.8, 13.7_

- [x] 26.4 販売確定・エラーハンドリング
  - 顧客区分（staff / citizen）選択
  - 販売確定ボタン
  - 在庫不足時のエラーメッセージ表示
  - 価格未設定時のエラーメッセージ表示（商品名と価格種別を含む）
  - 販売完了後のリダイレクト
  - _Requirements: 3.3, 3.4, 3.7, 16.2, 16.3_

- [x] 27. 追加発注画面実装
- [x] 27.1 (P) 追加発注フォーム画面
  - 販売先、商品、数量、発注時刻入力フォーム
  - 追加発注履歴一覧表示
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 28. 返品・返金画面実装
- [x] 28.1 返品フォーム画面
  - 元の Sale を選択、返品商品を選択
  - 返品理由入力フォーム
  - 返金額の計算・表示
  - _Requirements: 14.1, 14.2, 14.3, 14.6, 14.12_

- [x] 28.2 返金処理確認画面
  - 元の販売内容表示（商品、数量、金額）
  - 新規販売内容表示（返品分を除いた商品、再計算後の金額）
  - 返金額表示（差額）
  - 返金確定ボタン
  - _Requirements: 14.4, 14.5, 14.6, 14.7, 14.10, 14.11_

### Phase 14: Frontend - Dashboard & Reports

- [ ] 29. ダッシュボード画面実装
- [ ] 29.1 (P) ダッシュボード画面
  - 販売実績サマリー、在庫状況、追加発注履歴
  - 日別、期間別の販売実績表示
  - 人気商品ランキング表示
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 29.2 (P) グラフ表示（Chartkick + Chart.js）
  - 売上推移グラフ（折れ線グラフ）
  - 商品別販売数グラフ（棒グラフ）
  - 販売先別売上グラフ（円グラフ）
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

### Phase 15: Frontend - Stimulus Controllers

- [x] 30. POS 用 Stimulus コントローラー実装
- [x] 30.1 pos_controller.js 実装
  - 商品選択時のカート更新ロジック
  - クーポン枚数入力時の価格再計算
  - 価格内訳の動的表示
  - 在庫確認 API 呼び出し
  - _Requirements: 3.1, 3.2, 3.5, 3.6, 12.7, 13.7_

- [x] 30.2 inventory_controller.js 実装
  - リアルタイム在庫更新（Turbo Streams）
  - 在庫ゼロの視覚的識別
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

### Phase 16: Performance & Caching

- [ ] 31. Solid Cache 設定
- [ ] 31.1 (P) キャッシュ戦略実装
  - Catalog, CatalogPrice, Discount のキャッシュ
  - DailyInventory のキャッシュ（販売先・日付ごと）
  - キャッシュ無効化ロジック（商品更新、在庫更新時）
  - _Requirements: 11.3_

- [ ] 31.2 (P) インデックス最適化確認
  - 全インデックスの作成確認
  - スロークエリの特定
  - EXPLAIN ANALYZE での検証
  - _Requirements: 11.4_

### Phase 17: Responsive Design

- [ ] 32. レスポンシブデザイン実装
- [ ] 32.1 スマホ最適化（POS 画面）
  - Tailwind CSS responsive classes 適用
  - タッチ操作対応
  - フォントサイズ調整
  - _Requirements: 3.5, 10.1, 10.2_

- [ ] 32.2 PC 最適化（管理画面）
  - 管理画面のレイアウト調整
  - テーブル表示の最適化
  - _Requirements: 10.3, 10.4_

- [ ] 32.3 タブレット対応
  - 中間サイズのレイアウト調整
  - _Requirements: 10.5_

### Phase 18: Testing

- [ ] 33. モデルテスト実装
- [ ]* 33.1 Location モデルテスト
  - バリデーションテスト（name 必須、ユニーク性）
  - status enum テスト
  - deactivate/activate メソッドテスト
  - _Requirements: 15.1, 15.2, 15.3_

- [ ]* 33.2 Catalog モデルテスト
  - バリデーションテスト（name ユニーク、category 必須）
  - CatalogPrice, CatalogPricingRule, CatalogDiscontinuation の関連テスト
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 33.3 Discount モデルテスト
  - delegated_type パターンテスト
  - Coupon の applicable? メソッドテスト
  - calculate_discount メソッドテスト
  - _Requirements: 12.1, 12.4, 12.5_

- [ ]* 33.4 DailyInventory モデルテスト
  - バリデーションテスト（stock >= 0）
  - ユニーク制約テスト（location_id, catalog_id, inventory_date）
  - decrement_stock/increment_stock メソッドテスト
  - optimistic locking テスト
  - _Requirements: 2.1, 2.2, 2.4, 11.1, 11.2_

- [ ]* 33.5 Sale モデルテスト
  - バリデーションテスト（location_id 必須、status enum）
  - mark_as_voided! メソッドテスト
  - corrected_from_sale_id の関連テスト
  - _Requirements: 3.3, 14.1, 14.2_

- [ ]* 33.6 SaleItem モデルテスト
  - バリデーションテスト（quantity > 0, unit_price >= 0）
  - line_total 自動計算テスト（before_validation）
  - 純粋データモデルの確認（コールバックなし）
  - _Requirements: 3.1, 3.2, 3.4_

- [ ]* 33.7 Refund モデルテスト
  - バリデーションテスト（amount >= 0）
  - original_sale, corrected_sale の関連テスト
  - _Requirements: 14.10_

- [ ]* 33.8 AdditionalOrder モデルテスト
  - バリデーションテスト（quantity > 0）
  - after_create コールバックテスト（在庫加算）
  - _Requirements: 5.1, 5.2_

- [ ] 34. PORO テスト実装
- [ ]* 34.1 Sales::PriceCalculator テスト
  - 価格ルール適用テスト（セット価格）
  - 割引適用テスト（クーポン）
  - calculate メソッド統合テスト
  - 価格存在検証テスト（MissingPriceError 発生）
  - _Requirements: 3.1, 3.2, 12.8, 13.7, 16.1, 16.2, 16.3_

- [ ]* 34.2 Sales::Recorder テスト
  - record メソッドテスト（販売記録作成、在庫減算）
  - 在庫不足時のエラーテスト（InsufficientStockError）
  - 価格未設定時のエラーテスト（MissingPriceError）
  - トランザクションロールバックテスト
  - _Requirements: 3.1, 3.4, 3.7, 11.1, 11.2, 16.5, 16.6_

- [ ]* 34.3 Sales::Refunder テスト
  - refund メソッドテスト（取消、在庫復元、再販売、差額返金）
  - 全額返金テスト（全商品返品時、corrected_sale なし）
  - 既に取消済みの Sale に対する AlreadyVoidedError テスト
  - 価格ルール・クーポン再評価テスト（部分返品時の金額再計算）
  - StaleObjectError テスト（楽観的ロック競合）
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.9, 14.11_

- [ ]* 34.4 Sales::AnalysisCalculator テスト
  - calculate_sma メソッドテスト
  - predict_additional_order メソッドテスト
  - _Requirements: 6.2, 6.4_

- [ ]* 34.5 Reports::Generator テスト
  - generate_daily_report メソッドテスト
  - generate_period_report メソッドテスト
  - _Requirements: 7.2, 7.4_

- [ ]* 34.6 Catalogs::PriceValidator テスト
  - price_exists? メソッドテスト（正常系: 価格存在時は true）
  - price_exists? メソッドテスト（異常系: 価格未設定時は false）
  - find_price! メソッドテスト（価格未設定時に MissingPriceError）
  - catalogs_with_missing_prices メソッドテスト（管理画面用）
  - _Requirements: 16.1, 16.2, 17.1, 17.2_

- [ ]* 34.7 Catalog::PricingRuleCreator テスト
  - create メソッドテスト（正常系: 価格存在時に作成成功）
  - create メソッドテスト（異常系: 価格未設定時に MissingPriceError）
  - update メソッドテスト（有効化時の価格検証）
  - update メソッドテスト（無効化時の検証スキップ）
  - _Requirements: 18.1, 18.2, 18.3, 18.5, 18.6, 18.7_

- [ ] 35. コントローラーテスト実装
- [x]* 35.1 LocationsController テスト
  - CRUD アクションテスト（認証テスト含む）
  - deactivate アクションテスト
  - バリデーションエラーテスト
  - _Requirements: 15.1, 15.2, 15.3, 15.4_

- [ ]* 35.2 CatalogsController テスト
  - CRUD アクションテスト
  - CatalogDiscontinuation 作成テスト
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 35.3 DiscountsController テスト
  - CRUD アクションテスト
  - _Requirements: 12.1, 12.2_

- [ ]* 35.4 SalesController テスト
  - create アクションテスト（Sales::Recorder 呼び出し: 販売記録、在庫減算、割引適用）
  - void アクションテスト（Sales::Refunder 呼び出し: 返品・返金処理）
  - トランザクションテスト
  - 価格未設定時のエラーハンドリングテスト（MissingPriceError）
  - AlreadyVoidedError ハンドリングテスト
  - _Requirements: 3.1, 3.3, 3.4, 14.1, 14.2, 16.2, 16.3_

- [ ]* 35.5 AdditionalOrdersController テスト
  - create アクションテスト（追加発注記録、在庫加算）
  - _Requirements: 5.1, 5.2_

- [ ]* 35.6 DashboardController テスト
  - index アクションテスト
  - JSON エンドポイントテスト
  - _Requirements: 7.1, 8.1_

- [ ] 36. 統合テスト実装
- [ ]* 36.1 販売フロー統合テスト
  - 販売先選択 → 商品選択 → 価格計算 → 販売確定 → 在庫減算
  - クーポン適用 → 価格再計算
  - セット価格適用 → 価格再計算
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 12.8, 13.7_

- [ ]* 36.2 返品・返金フロー統合テスト
  - Sales::Refunder 呼び出し: 販売取消 → 在庫復元 → 新規販売作成 → 返金額計算
  - 全商品返品 → 全額返金
  - 部分返品 → 価格ルール・クーポン再評価 → 差額返金
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.9, 14.11_

- [ ]* 36.3 追加発注フロー統合テスト
  - 追加発注記録 → 在庫加算
  - _Requirements: 5.1, 5.2_

- [ ]* 36.4 価格未設定商品の会計エラーフロー統合テスト
  - 価格ルールに対応する CatalogPrice が存在しない商品をカートに追加
  - 会計確定 → Sales::PriceCalculator.calculate で MissingPriceError 発生
  - エラーメッセージ表示（商品名と価格種別を含む）、在庫減算なし
  - _Requirements: 16.1, 16.2, 16.3, 16.5, 16.6_

- [ ]* 36.5 価格ルール作成・有効化時の価格検証統合テスト
  - 価格が存在しない商品に対して価格ルールを作成 → エラー
  - 価格を追加後に価格ルールを作成 → 成功
  - 既存ルールを有効化（価格なし）→ エラー
  - _Requirements: 18.1, 18.2, 18.3, 18.6_

- [ ] 37. E2E テスト実装（System tests）
- [ ]* 37.1 POS 画面 E2E テスト
  - 販売先選択 → 商品選択 → クーポン入力 → 販売確定
  - スマホサイズでの操作確認
  - _Requirements: 3.1, 3.2, 3.3, 3.5_

- [ ]* 37.2 管理画面 E2E テスト
  - 商品登録 → 在庫登録 → 販売実績確認
  - _Requirements: 1.1, 2.1, 7.1_

### Phase 19: Integration & Final Checks

- [ ] 38. システム統合
- [ ] 38.1 全機能統合確認
  - Location, Catalog, Discount, DailyInventory, Sale, SaleItem, SaleDiscount, Refund, AdditionalOrder の連携確認
  - Sales::PriceCalculator の統合確認（価格存在検証を含む）
  - Sales::Recorder, Sales::Refunder の統合確認
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 12.8, 13.7, 14.1, 14.2, 16.1, 16.4_

- [ ] 38.2 データ整合性確認
  - 在庫数の整合性（販売、返品、追加発注）
  - 販売金額の整合性（価格ルール、割引）
  - 返金額の整合性
  - _Requirements: 11.4, 11.5_

- [ ] 38.3 パフォーマンス確認
  - スロークエリの特定と最適化
  - キャッシュの有効性確認
  - N+1 クエリの検出と修正
  - _Requirements: 11.3, 11.4_

- [ ] 39. セキュリティ確認
- [ ] 39.1 (P) 認証チェック
  - 未認証ユーザーが保護されたページにアクセスするとログインページにリダイレクト
  - _Requirements: 9.4_

- [ ] 39.2 (P) CSRF 保護確認
  - form_with での CSRF トークン確認
  - _Requirements: 9.1_

- [ ] 39.3 (P) SQL インジェクション対策確認
  - ActiveRecord の prepared statement 確認
  - _Requirements: 11.1_

---

## Requirements Coverage

全 18 の要件にマッピング済み:

- **Requirement 1**: 弁当商品マスタ管理 → Tasks 4, 18.2, 23, 33.2, 35.2, 37.2
- **Requirement 2**: 販売先ごとの在庫登録 → Tasks 6, 33.4（POS フロー内での在庫登録は Task 26.1 で実装済み）
- **Requirement 3**: 販売記録（POS機能） → Tasks 7, 8, 19.1, 26, 30.1, 32.1, 33.5, 33.6, 34.2, 35.4, 36.1, 37.1
- **Requirement 4**: リアルタイム在庫確認 → Tasks 26.1, 26.2, 30.2（POS画面に統合済み: 商品カードに在庫バッジ表示、ghost form による最新在庫取得）
- **Requirement 5**: 追加発注記録 → Tasks 15, 19.2, 27, 33.8, 35.5, 36.3
- **Requirement 6**: 販売データ分析 → Tasks 16, 20.2, 34.4
- **Requirement 7**: 販売実績レポート → Tasks 17, 20.1, 29.1, 34.5, 35.6, 37.2
- **Requirement 8**: 販売データ可視化 → Tasks 20.1, 29.2
- **Requirement 9**: 認証 → Tasks 2, 21, 39
- **Requirement 10**: レスポンシブデザイン → Tasks 32
- **Requirement 11**: データ整合性とパフォーマンス → Tasks 1, 6, 31, 38.2, 38.3, 39
- **Requirement 12**: 割引（クーポン）管理と適用 → Tasks 5, 9, 10.3, 18.3, 24, 26.2, 26.3, 30.1, 33.3, 35.3, 36.1
- **Requirement 13**: サイドメニュー（サラダ）の条件付き価格設定 → Tasks 4.2, 4.3, 10.2, 23.1, 26.3, 30.1, 36.1
- **Requirement 14**: 返品・返金処理（取消・再販売・差額返金） → Tasks 7, 13, 14, 19.1, 28, 33.5, 33.7, 34.3, 35.4, 36.2
- **Requirement 15**: 販売先（ロケーション）管理 → Tasks 3, 6.1, 7.1, 15.1, 18.1, 22, 26.1, 33.1, 35.1
- **Requirement 16**: 価格ルール適用時の価格存在検証 → Tasks 10.4, 11.1, 11.2, 11.4, 11.5, 26.4, 34.1, 34.2, 35.4, 36.4
- **Requirement 17**: 管理画面での価格設定不備の警告表示 → Tasks 11.3, 25, 34.6
- **Requirement 18**: 価格ルール作成・有効化時の価格存在バリデーション → Tasks 12, 34.7, 36.5

---

## Task Summary

- **総タスク数**: 39 major tasks, 108 sub-tasks
- **並列実行可能タスク**: 36 tasks marked with `(P)`
- **オプショナルテストタスク**: 27 tasks marked with `*` (deferrable post-MVP)
- **平均タスクサイズ**: 1-3 hours per sub-task
- **要件マッピング**: 18/18 requirements

**変更履歴 (2026-02-01)**:
- Requirement 9 の大幅簡素化に伴い、認証関連タスクを再構成:
  - Task 2.1（Admin 認証セットアップ）を削除、Task 2.2（Employee 認証セットアップ）に統合
  - Task 2.3（Employee 管理画面の認可制御）を削除
  - 旧 Task 18.4（EmployeesController）を削除
  - 旧 Task 25（Employee 管理画面）を削除
  - 旧 Task 40.1（認可チェック）を簡素化（Admin/Employee の区別なし）
- Employee の登録・編集・削除は Rails console で行う（管理画面は不要: Requirement 9.9）
- タスク番号を 18.4 以降で繰り下げ調整

**変更履歴 (2026-01-31)**:
- Requirement 9 更新に伴い Task 2.1 を更新（認証方式を email → username に変更）
- created_by_admin_id 関連を削除（Admin と Employee の関連削除）
- Rodauth 設定: `login_column :username`, `require_email_address_logins? false`

**変更履歴 (2026-01-28 追加)**:
- 旧 Task 28（リアルタイム在庫確認画面）を削除
- Requirement 4 の全 AC は POS 画面に統合済み（商品カードに在庫バッジ表示、ghost form による最新在庫取得、売り切れ視覚識別、販売先選択による切り替え）

**変更履歴 (2026-01-28)**:
- 旧 Task 18.4（独立 DailyInventoriesController）、旧 Task 25（DailyInventory 管理画面）、旧 Task 38.4（DailyInventoriesController テスト）を削除
- Requirement 2 の AC 5（在庫一覧表示）と AC 6（販売先フィルタリング）が削除されたため
- POS フロー内での在庫登録（Pos::Locations::DailyInventoriesController）は Task 26.1 で実装済み

---

**次のステップ**: タスクを確認後、`/kiro:spec-impl sales-tracking-pos` で未実装タスクの実装を開始してください。
