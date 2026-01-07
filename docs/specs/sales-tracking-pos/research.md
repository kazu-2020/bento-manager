# Research Log

## Discovery Phase - 2026-01-03

### R1: Rodauth-Rails マルチアカウントセットアップ

**調査目的**: Admin と Employee を別テーブルで管理するための Rodauth-Rails の設定方法を調査

**調査結果**:
- Rodauth-Rails は複数のアカウントタイプを別テーブルで管理する構成をサポート
- 推奨アプローチ:
  - 各アカウントタイプ用の別々の Rodauth 設定を作成
  - `config/initializers/rodauth_admin.rb` と `config/initializers/rodauth_employee.rb`
  - 各設定で異なる `accounts_table`, `prefix`, `session_key` を指定
- 例:
  ```ruby
  # Admin用
  rodauth do
    enable :login, :logout, :change_password
    accounts_table :admins
    prefix "/admin"
    session_key :admin_account_id
  end

  # Employee用
  rodauth do
    enable :login, :logout, :change_password
    accounts_table :employees
    prefix "/employee"
    session_key :employee_account_id
  end
  ```

**設計への影響**:
- Admin と Employee で別々の Rodauth 設定ファイルを作成
- ルーティングも `/admin/login`, `/employee/login` のように分離
- セッションキーを分離して同時ログインの混乱を防止

**情報源**: Rodauth-Rails 公式ドキュメント、GitHub issues、実装例

---

### R2: Chartkick + Chart.js の Rails 統合

**調査目的**: データ可視化機能（Requirement 8）を実現するための Chartkick と Chart.js の統合方法を調査

**調査結果**:
- Chartkick は Rails フレンドリーなグラフライブラリで、Chart.js をデフォルトアダプターとして使用
- ベストプラクティス:
  - 非同期エンドポイントからデータをロード: `line_chart sales_data_path`
  - グラフのリフレッシュオプション: `refresh: 60` で自動更新
  - Turbo Frames との統合でページ全体のリロードなしにグラフ更新
- パフォーマンス最適化:
  - JSON エンドポイントでデータを返す（View から分離）
  - 大量データの場合は集約済みデータを返す
- Vite 統合:
  ```javascript
  // app/frontend/entrypoints/application.js
  import "chartkick"
  import "Chart.bundle"
  ```

**設計への影響**:
- `DashboardController` に JSON エンドポイントを追加（`sales_trend_data`, `product_sales_data`, `customer_breakdown_data`, `weekday_trend_data`）
- Chartkick gem を Gemfile に追加
- Chart.js を package.json に追加し、Vite でバンドル
- Turbo Frame で Dashboard をラップして部分更新

**情報源**: Chartkick 公式ドキュメント、Rails + Vite 統合ガイド

---

### R3: Service Worker を使った Rails Hotwire でのオフライン同期

**調査目的**: Requirement 11（オフライン対応）を実現するための Service Worker と Rails Hotwire の統合方法を調査

**調査結果**:
- Turbo に新しいオフライン支援機能が追加（2025年、PR #1427）
- 公式サポート内容:
  - Service Worker 用のキャッシング戦略（network-first, cache-first, stale-while-revalidate）
  - オフライン時の自動リトライ機構
  - オフライン検出と UI 通知
- Rails World 2025 での発表あり
- 実装パターン:
  ```javascript
  // service-worker.js
  import { Turbo } from "@hotwired/turbo-rails"

  self.addEventListener('fetch', (event) => {
    // Turbo のオフライン処理
  })
  ```
- LocalStorage + IndexedDB でオフライン時の販売記録を保存
- 復帰時に Turbo Streams で同期

**設計への影響**:
- Service Worker ファイルを `app/frontend/entrypoints/service-worker.js` に作成
- オフライン販売記録用に Stimulus Controller を作成（`offline_sync_controller.js`）
- LocalStorage に未同期の販売記録を保存
- ネットワーク復帰時に `/api/sales/sync` エンドポイントにバッチ送信
- 競合検出とエラーハンドリング機構

**情報源**: Turbo GitHub PR #1427、Rails World 2025 発表資料、Service Worker ベストプラクティス

---

### R4: Rails 8 Turbo Streams ブロードキャストパターン

**調査目的**: Requirement 4（リアルタイム在庫確認）を実現するための Turbo Streams ブロードキャスト方法を調査

**調査結果**:
- Rails 8 では3つのブロードキャストパターンをサポート:
  1. **Convention-based**: `broadcasts_to "inventory"` をモデルに宣言
  2. **Callback-based**: `after_update_commit { broadcast_replace_later_to('inventory', :inventory_item) }`
  3. **Reactive pattern**: `broadcasts_to` + Job エンキュー（Rails 8 推奨）
- Solid Cable（SQLite バックバンド）を使用してインフラ複雑性を削減
- チャンネルのサブスクリプション:
  ```erb
  <%= turbo_stream_from "inventory" %>
  ```
- 部分更新の partial 指定:
  ```ruby
  broadcast_replace_to "inventory",
                       target: "bento_item_#{id}",
                       partial: "bento_items/inventory_item",
                       locals: { item: self }
  ```

**設計への影響**:
- `DailyInventory` モデルに `broadcasts_to "inventory_#{date}"` を追加
- `Sale` 作成時に `after_create_commit` で在庫ブロードキャスト
- 販売員画面に `turbo_stream_from "inventory_#{Date.today}"` を追加
- Partial `_inventory_item.html.erb` を作成（在庫数とステータス表示）
- Solid Cable を使用（既存の cable データベースを活用）

**情報源**: Rails 8 リリースノート、Turbo Handbook、Solid Cable ドキュメント

---

### R5: Ruby での移動平均による販売予測アルゴリズム

**調査目的**: Requirement 6（販売データ分析・追加発注支援）の予測アルゴリズムを調査

**調査結果**:
- Ruby には移動平均を扱う gem が存在（`moving_avg-ruby`, `moving_averages`）
- シンプルな実装では Proc ベースのアプローチも可能
- 推奨アルゴリズム（段階的実装）:
  1. **Simple Moving Average (SMA)**: 過去4週間の同一曜日・同一時間帯の平均
  2. **Weighted Moving Average (WMA)**: 直近データに重み付け
  3. **Exponential Moving Average (EMA)**: 長期的なトレンド追跡（将来拡張）
- 実装例:
  ```ruby
  # Simple Moving Average
  def calculate_sma(sales_data, window_size = 4)
    return 0 if sales_data.size < window_size
    sales_data.last(window_size).sum / window_size.to_f
  end
  ```
- エッジケース:
  - データ不足（4週未満）: 警告を表示し、利用可能なデータで計算
  - 異常値処理: 外れ値除去（IQR 方式）

**設計への影響**:
- `SalesAnalysisService` サービスオブジェクトを作成
- メソッド:
  - `predict_additional_order(bento_item, current_time)` - 推奨追加発注数を計算
  - `historical_sales(bento_item, weekday, time_range, weeks)` - 過去データ取得
  - `calculate_sma(sales_data)` - 単純移動平均
- 標準偏差を計算して信頼区間を提示（オプション）
- データ不足時の警告メッセージ機構

**情報源**: Ruby 統計処理 gem、移動平均アルゴリズム論文、時系列予測ベストプラクティス

---

## 技術選定まとめ

| 要件 | 採用技術 | 理由 |
|-----|---------|------|
| Req 9: 認証 | Rodauth-Rails | マルチアカウントタイプ対応、セキュリティ標準準拠 |
| Req 8: 可視化 | Chartkick + Chart.js | Rails フレンドリー、Vite 統合容易 |
| Req 11: オフライン | Service Worker + LocalStorage | Turbo の新機能、IndexedDB でデータ永続化 |
| Req 4: リアルタイム | Turbo Streams + Solid Cable | Rails 8 標準、インフラシンプル |
| Req 6: 販売予測 | SMA アルゴリズム | 実装容易、段階的改善可能 |

---

---

### R6: Rails Delegated Type パターンのベストプラクティス

**調査目的**: Catalog と Discount モデルで delegated_type を使用する際のベストプラクティスを調査

**調査結果**:
- 37signals が2024年後半に公開した記事で、delegated types が Basecamp を10年以上スケールさせた実績を紹介
- **主要なベストプラクティス**:
  1. **ポリモーフィズムを活用**: 型チェック(`if catalogable_type == 'Bento'`)はアンチパターン。ポリモーフィックなメソッドを定義
  2. **アーキテクチャの利点**: 各タイプが独自のテーブルを持つため、データモデルが整理され、将来的な拡張が容易
  3. **パフォーマンス最適化**: Rails の association caching を活用し、eager-loading で効率化
  4. **実例**: Basecamp では documents, messages, comments, uploads を delegated types で実装
- **推奨パターン**:
  ```ruby
  # 抽象モデル
  class Catalog < ApplicationRecord
    delegated_type :catalogable, types: %w[Bento SideMenu]
    delegate :description, to: :catalogable
  end

  # 具象モデル
  class Bento < ApplicationRecord
    has_one :catalog, as: :catalogable, touch: true
  end
  ```

**設計への影響**:
- Catalog と Discount モデルで delegated_type を使用する設計を確認
- ポリモーフィックなメソッド(`current_price`, `applicable?`)を抽象モデルで定義
- eager-loading で N+1 問題を回避（`Catalog.includes(:catalogable)`）
- 型チェックを最小限に抑え、委譲パターンを活用

**情報源**:
- [37signals Dev — The Rails Delegated Type Pattern](https://dev.37signals.com/the-rails-delegated-type-pattern/)
- [ActiveRecord::DelegatedType - Rails API](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html)
- [Delegated Types in Rails: Mastering Ruby on Rails | Medium](https://medium.com/nyc-ruby-on-rails/delegated-types-in-rails-mastering-ruby-on-rails-b4c49395e5ec)

---

### R7: Rails 楽観的ロックと競合解決戦略

**調査目的**: 在庫更新時の競合を検出・解決するための楽観的ロックのベストプラクティスを調査

**調査結果**:
- Rails は `lock_version` カラムがあれば自動的に楽観的ロックを有効化
- **実装ベストプラクティス**:
  1. **フォームに lock_version を含める**: hidden field として追加し、Web リクエスト間の競合を検出
  2. **ActiveRecord::StaleObjectError をハンドリング**: Controller レベルで rescue し、ユーザーに通知
  3. **競合解決戦略の選択**:
     - ロールバック: ユーザーに再読み込みを促す
     - マージ: 現在のバージョンとユーザーのバージョンを並べて表示
     - ビジネスロジックに基づく自動解決
  4. **適用ケース**: 読み取り:書き込み比率が高く、競合が稀だが検出が必要な場合
- **エラーハンドリング例**:
  ```ruby
  def update
    @inventory.update!(params)
  rescue ActiveRecord::StaleObjectError
    flash[:error] = "在庫が他のユーザーによって更新されました。再読み込みしてください。"
    redirect_to inventory_path(@inventory)
  end
  ```

**設計への影響**:
- `DailyInventory` モデルに `lock_version` カラムを追加（既に設計に含まれている）
- `SalesController#create` で StaleObjectError を rescue
- オフライン同期時の競合は、最新の在庫数を表示してユーザーに再試行を促す
- 在庫減算時に楽観的ロックで競合を検出し、エラーメッセージを返す

**情報源**:
- [ActiveRecord::Locking::Optimistic - Rails API](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html)
- [Understanding Locking in Rails: Optimistic vs. Pessimistic Strategies | Medium](https://medium.com/@radadiyahardik355/understanding-locking-in-rails-optimistic-vs-pessimistic-strategies-a48530e2245e)
- [Understanding Optimistic and Pessimistic Locking in Ruby on Rails - DEV Community](https://dev.to/jetthoughts/understanding-optimistic-and-pessimistic-locking-in-ruby-on-rails-2fo)

---

## アーキテクチャパターンの評価

| パターン | 説明 | 強み | リスク・制約 | 備考 |
|---------|------|------|------------|------|
| Rails MVC + Hotwire | 標準的な Rails アーキテクチャ + Turbo/Stimulus | プロジェクト標準に準拠、チーム知見あり、インフラシンプル | SPA に比べてクライアント側の柔軟性が低い | Steering に準拠、選択済み |
| Rails + React SPA | Rails API + React フロントエンド | 高度なクライアント側インタラクション | 複雑性増加、ビルド時間増、プロジェクト標準外 | 却下：複雑性とプロジェクト標準外 |
| Service Objects パターン | ビジネスロジックを Service オブジェクトに分離 | コントローラーがシンプル、テストしやすい | Steering が禁止、PORO で代替 | 却下：Steering 違反 |

**選択**: Rails MVC + Hotwire（Fat Models, Skinny Controllers + PORO）

---

## 設計決定

### 決定1: 1在庫1レコード方式の採用

**コンテキスト**: 在庫管理と販売記録の関連付け方法を決定する必要がある

**検討した選択肢**:
1. **数量ベース方式**: DailyInventory に quantity カラムを持ち、販売時に減算
2. **1在庫1レコード方式**: 各在庫を1レコードとし、status で管理（unsold/consumed/reserved/cancelled）

**選択したアプローチ**: 1在庫1レコード方式

**理由**:
- 各弁当の販売履歴を個別に追跡可能（トレーサビリティ）
- 販売時の価格を個別に記録できる（価格変更対応）
- 在庫の予約や取り消しを柔軟に実装可能
- 楽観的ロックとの相性が良い（レコード単位でロック）

**トレードオフ**:
- メリット: トレーサビリティ、柔軟性、価格履歴管理
- デメリット: レコード数増加（1日50個 × 365日 = 年間18,250レコード程度、SQLite で問題なし）

**フォローアップ**: パフォーマンステスト（1万レコード規模でクエリ速度確認）

---

### 決定2: Discount モデルを Catalog から独立

**コンテキスト**: 割引・クーポン機能をどのように実装するか

**検討した選択肢**:
1. Catalog モデルに discount_price カラムを追加
2. Discount を独立したモデルとして実装

**選択したアプローチ**: Discount を独立したモデルとして実装

**理由**:
- 複数種類の割引（クーポン、セット割引）を柔軟に実装可能
- 有効期間や条件を独立して管理できる
- 将来的な拡張（会員割引、期間限定セールなど）に対応しやすい
- Catalog モデルの責務を単純に保つ

**トレードオフ**:
- メリット: 拡張性、柔軟性、責務分離
- デメリット: テーブル数増加、JOIN クエリ増加

---

### 決定3: 数量ベース方式への変更（DailyInventory の設計変更）

**コンテキスト**: 「個体（弁当1個）」を識別することと「どの売上明細で、どの商品が、何個売れたか」を追えることは別であることが判明。追跡すべきなのは「個体」ではなく「取引」である。

**検討した選択肢**:
1. **1在庫1レコード方式**: 各在庫を1レコードとし、status で管理（unsold/consumed/reserved/cancelled）
2. **数量ベース方式**: DailyInventory に stock カラムを持たせ、販売時に減算
3. **delegated_type 状態管理**: DailyInventoryStatus を delegated_type で実装し、状態ごとにテーブル分離

**選択したアプローチ**: 数量ベース方式（stock カラム）

**理由**:
- **取引追跡に特化**: SaleItem で「どの売上で、どの商品が、何個売れたか」を追跡
- **シンプルな在庫管理**: stock カラムで在庫数を直接管理（レコード数削減）
- **パフォーマンス向上**: 在庫数集計が高速（< 5ms、単一レコード参照）
- **予約管理の実現**: reserved_stock カラムで予約確保数を管理
- **nullable カラムの排除**: すべてのカラムが NOT NULL

**トレードオフ**:
- メリット: シンプル、高速、予約管理可能
- デメリット: 個体識別不可（ビジネス要件では不要）、廃棄履歴なし（将来的に WasteLog テーブルで対応可能）

**設計詳細**:
- DailyInventory: id, catalog_id, inventory_date, stock, reserved_stock, lock_version
- SaleItem: id, sale_id, catalog_id, catalog_price_id, quantity, sold_at
- Sale: has_many :sale_items

**パフォーマンス目標**:
- 在庫数集計: < 5ms（単一レコード参照）
- 年間レコード数: 365レコード（1日1商品1レコード）

**フォローアップ**: 楽観的ロックの競合テスト、在庫減算の並行性テスト

### 決定4: 複数割引対応（中間テーブル方式）

**コンテキスト**: 1つの販売（Sale）に対して複数の割引を同時適用する必要があることが判明。例: クーポン10%割引 + セット割引50円引き。現在の設計では `Sale belongs_to :discount`（1対多）のため、複数割引を適用できない。

**検討した選択肢**:
1. **単一割引方式**: Sale が1つの Discount のみを参照（現行設計）
2. **中間テーブル方式**: SaleDiscount 中間テーブルで Sale と Discount の多対多関係を実現
3. **JSON 配列方式**: Sale に discount_ids を JSON カラムで保存

**選択したアプローチ**: 中間テーブル方式（SaleDiscount）

**理由**:
- **柔軟性**: 異なる複数の割引を組み合わせて適用可能（例: クーポンA + セット割引B）
- **データ整合性**: 同じ割引の重複適用を DB 制約（UNIQUE: sale_id, discount_id）とバリデーションで防止
- **個別記録**: 各割引の適用額を SaleDiscount.discount_amount に保存（監査トレイル）
- **拡張性**: 将来的な割引ルール追加が容易（優先順位、組み合わせ制約など）
- **Rails 標準**: has_many :through パターンで実装がシンプル

**トレードオフ**:
- メリット: 柔軟性、拡張性、データ整合性、監査トレイル
- デメリット: テーブル数増加（+1）、JOIN クエリの複雑化、PriceCalculator の実装複雑化

**設計詳細**:
- SaleDiscount: id, sale_id, discount_id, discount_amount, created_at, updated_at
- Sale: has_many :sale_discounts, has_many :discounts, through: :sale_discounts
- Discount: has_many :sale_discounts, has_many :sales, through: :sale_discounts
- ユニーク制約: idx_sale_discounts_unique (UNIQUE: sale_id, discount_id)
- 割引適用ルール: 異なる割引は複数適用可能、同じ割引（discount_id）の重複適用は不可

**パフォーマンス影響**:
- JOIN が1つ増えるが、sale_discounts テーブルは小規模（1販売あたり1-3レコード程度）
- ユニークインデックス（idx_sale_discounts_unique）で検索最適化と整合性担保
- 複数割引適用時の計算コストは O(N)（N = 割引数、通常1-3）

**フォローアップ**: 複数割引適用時の価格計算テスト、重複適用エラーのハンドリングテスト

---

## リスクと緩和策

1. **オフライン同期の競合**:
   - リスク: 複数デバイスからの同時販売記録時の在庫競合
   - 緩和策: 楽観的ロックで検出し、最新の在庫数を表示してユーザーに再試行を促す

2. **予測精度の初期データ不足**:
   - リスク: 稼働初期は過去データが少なく、予測精度が低い
   - 緩和策: データ不足時は警告メッセージを表示し、利用可能なデータで計算（最低2週間のデータを推奨）

3. **Rodauth のカスタマイズ複雑性**:
   - リスク: Admin と Employee の権限分離が複雑になる可能性
   - 緩和策: 初期実装では Admin のみが Employee CRUD を実行可能にし、段階的に権限機能を追加

---

## 参照

- [37signals Dev — The Rails Delegated Type Pattern](https://dev.37signals.com/the-rails-delegated-type-pattern/)
- [ActiveRecord::DelegatedType - Rails API](https://api.rubyonrails.org/classes/ActiveRecord/DelegatedType.html)
- [ActiveRecord::Locking::Optimistic - Rails API](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html)
- [Rodauth Documentation](https://rodauth.jeremyevans.net/)
- [Chartkick Documentation](https://chartkick.com/)
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Service Worker API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)

---

## Discovery Phase 2 - 2026-01-04（新仕様追加）

### R8: Rails Enum (String vs Integer) ベストプラクティス

**調査目的**: CatalogPrice.kind フィールドに String Enum と Integer Enum のどちらを使用するか決定

**調査結果**:
- Rails コミュニティは **String-based Enums** を推奨する方向にシフト
- **String Enum の利点**:
  - データベース可読性向上（クエリやログで値が明示的）
  - 将来の拡張性（値の追加・並び替えが容易）
  - デバッグの容易さ（データ表現が明確）
  - Data チームや Rails 以外のツールがデータを読む場合に有利
- **Integer Enum の利点**:
  - パフォーマンス向上（クエリとインデックスが高速）
  - ストレージ削減（約10%のストレージ差、1000万レコードで86MB）
- **パフォーマンス現実**:
  - enum キーが短い場合、ストレージ差はわずか
  - 実行時間の差も小さい（インデックスで緩和可能）

**設計への影響**:
- CatalogPrice.kind に **String Enum** を採用
- 理由: データベース可読性とデバッグ容易性を優先（パフォーマンス差は小規模システムでは無視可能）
- 定義: `enum kind: { regular: 'regular', bundle: 'bundle' }`

**情報源**:
- [Integer Enums vs. String Enums in Rails: Which One Should You Use? | Medium](https://medium.com/@railsforge/integer-enums-vs-string-enums-in-rails-which-one-should-you-use-9980196fc425)
- [Rails enums integer vs string way | by Michał Rudzki | Medium](https://medium.com/@michal.a.rudzki/rails-enums-integer-vs-string-way-0cb5e34daf7f)
- [The 3 kinds of Enum in Rails - DEV Community](https://dev.to/epigene/the-3-kinds-of-enum-in-rails-3koe)

---

### R9: Rails Calculated Fields (Stored vs Computed) ベストプラクティス

**調査目的**: SaleItem.line_total や Sale.final_amount を保存すべきか、計算プロパティにすべきか決定

**調査結果**:
- **Stored（保存）を推奨する場合**:
  - フィールドが頻繁にアクセスされる
  - 計算が複数の関連レコードを読み込む（コスト高）
  - データが頻繁に変わらない
  - パフォーマンスが重要
- **Computed（計算）を推奨する場合**:
  - 計算がシンプル
  - データが頻繁に変わる
  - ストレージ削減と鮮度維持を優先
- **Rails 7 Generated Columns（Postgres 12+）**:
  - Virtual（stored: false）: アクセス時に毎回再計算
  - Stored（stored: true）: 挿入・更新時に計算して保存
  - データベースが自動的に最新状態を保持

**設計への影響**:
- SaleItem.line_total: **Stored** を採用（頻繁にアクセス、計算はシンプル）
- Sale.final_amount: **Stored** を採用（合計金額は頻繁に参照される）
- 理由: 販売記録は作成後に変更されないため、保存して読み取り速度を最適化
- 実装: 通常のカラムとして保存（Rails 7 Generated Columns は将来検討）

**情報源**:
- [Saving Calculated Fields in Ruby on Rails 5 – russt](https://russt.me/2018/06/saving-calculated-fields-in-ruby-on-rails-5/)
- [Rails 7 now introduces support for generated columns with Postgres | Saeloun Blog](https://blog.saeloun.com/2022/01/25/rails-7-postgres-support-for-generated-columns/)
- [PostgreSQL generated columns in Rails - Tejas' Blog](https://tejasbubane.github.io/posts/2021-12-18-rails-7-postgres-generated-columns/)

---

### R10: Void/Cancellation/Refund パターン

**調査目的**: 返品・取消・返金処理のベストプラクティスを調査

**調査結果**:
- **Void vs Refund の違い**:
  - **Void**: 決済前に取り消し（決済手数料なし、顧客に請求なし）
  - **Refund**: 決済後に返金（決済手数料発生、顧客に返金）
- **Rails パターン**（支払いゲートウェイ API より）:
  - State Machine（AASM, Statesman）で状態管理が一般的
  - Void は決済前、Refund は決済後の処理
  - 部分返金と全額返金をサポート
- **本システムへの適用**:
  - Void: Sale を void 状態にし、在庫を復元、新しい Sale を作成
  - Refund: void した Sale と新しい Sale の差額を Refund レコードに記録
  - 取消→再販売パターン（仕様 A）を採用

**設計への影響**:
- Sale に void 関連フィールドを追加:
  - status（completed / voided）
  - voided_at, voided_by_employee_id, void_reason
  - corrected_from_sale_id（元の Sale を参照）
- Refund モデル新設:
  - original_sale_id, corrected_sale_id, amount, reason
- 在庫復元ロジック:
  - void 時: DailyInventory.stock += 元 Sale の数量
  - 再販売時: DailyInventory.stock -= 新 Sale の数量
- トランザクション内で原子性を保証

**情報源**:
- [What is a void transaction? - Checkout.com](https://www.checkout.com/blog/what-is-a-void-transaction)
- [Canceled payment: Void Transaction: The Cancellation of a Payment - FasterCapital](https://fastercapital.com/content/Canceled-payment--Void-Transaction--The-Cancellation-of-a-Payment.html)

---

## 設計決定（追加）

### 決定5: CatalogPrice.kind に String Enum を採用

**コンテキスト**: サラダのセット価格（bundle）と通常価格（regular）を区別する必要がある

**選択したアプローチ**: String Enum（`enum kind: { regular: 'regular', bundle: 'bundle' }`）

**理由**:
- データベース可読性優先（クエリやログで値が明示的）
- パフォーマンス差は小規模システムでは無視可能（約10%のストレージ差）
- 将来的な価格種別追加が容易

**トレードオフ**:
- メリット: 可読性、デバッグ容易性、拡張性
- デメリット: ストレージが Integer より約10%増加（小規模システムでは無視可能）

---

### 決定6: SaleItem.line_total と Sale.final_amount を Stored

**コンテキスト**: 販売金額を保存すべきか、計算プロパティにすべきか

**選択したアプローチ**: Stored（通常のカラムとして保存）

**理由**:
- 販売記録は作成後に変更されない（Immutable）
- 合計金額は頻繁に参照される（レポート、分析）
- 計算コストを削減（読み取り速度最適化）

**トレードオフ**:
- メリット: 読み取り速度向上、レポート生成高速化
- デメリット: ストレージ増加（わずか）、書き込み時に計算必要

---

### 決定7: 返品・取消は「Void → 再販売」パターンを採用

**コンテキスト**: 返品や販売訂正をどのように処理するか

**選択したアプローチ**: 取消（void）→ 再販売パターン（仕様 A）

**理由**:
- Sale は不変（Immutable）に保つ（監査トレイル）
- 価格ルールや割引を再評価できる
- 在庫復元と再販売をトランザクション内で原子的に実行
- 返金額は差額で計算（元 Sale.final_amount - 新 Sale.final_amount）

**トレードオフ**:
- メリット: 監査トレイル、価格ルール再評価、トランザクション整合性
- デメリット: Sale レコード数増加、在庫復元ロジックの複雑化

**設計詳細**:
- Sale に void フィールド追加（status, voided_at, voided_by_employee_id, void_reason, corrected_from_sale_id）
- Refund モデル新設（original_sale_id, corrected_sale_id, amount, reason）
- 在庫復元: void 時に stock += quantity、再販売時に stock -= quantity

---

### 決定8: SetDiscount 削除、CatalogPricingRule で価格ルール管理

**コンテキスト**: サラダのセット価格をどのように管理するか

**選択したアプローチ**: CatalogPricingRule テーブル新設、SetDiscount 削除

**理由**:
- セット価格は「割引」ではなく「価格ルール」として扱う
- CatalogPricingRule で条件（trigger_category, max_per_trigger）を明確化
- CatalogPrice.kind で価格種別を管理（regular / bundle）
- 将来的な価格ルール追加が容易（例: 会員価格、期間限定価格）

**トレードオフ**:
- メリット: 価格ルールの明確化、拡張性、責務分離
- デメリット: テーブル数増加（+1）、価格計算ロジックの複雑化

**設計詳細**:
- CatalogPricingRule: target_catalog_id, price_kind, trigger_category, max_per_trigger, valid_from, valid_until
- 例: サラダのセット価格ルール
  - target_catalog_id: サラダの catalog_id
  - price_kind: 'bundle'
  - trigger_category: 'bento'
  - max_per_trigger: 1（弁当1個につきサラダ1個まで）

---

## Discovery Phase 3 - 2026-01-04（販売先（ロケーション）追加）

### R11: Rails 論理削除パターン（deleted_at vs 専用テーブル）

**調査目的**: Location モデルで論理削除を実装する際のベストプラクティスを調査

**調査結果**:
- **deleted_at パターン**: テーブルに deleted_at カラムを追加し、削除フラグとして使用
- **専用テーブルパターン**: CatalogDiscontinuation のように専用テーブルで削除情報を管理

**本システムでの適用**:
- Catalog: CatalogDiscontinuation テーブル（専用テーブルパターン）
  - 理由: 廃止理由や詳細情報を記録、1 カタログにつき 1 回の廃止のみ
- Location: deleted_at カラム（deleted_at パターン）
  - 理由: シンプルな論理削除、削除理由の記録は不要、ActiveRecord の default_scope で除外可能

**設計への影響**:
- Location モデルに deleted_at カラムを追加
- デフォルトスコープで deleted_at IS NULL のレコードのみ取得
- 削除時は `update(deleted_at: Time.current)` で論理削除

---

### 決定9: Location モデルの追加（販売先管理）

**コンテキスト**: Requirement 16 で販売先（ロケーション）管理機能が追加された。複数の販売先を管理し、販売先ごとに在庫を管理する必要がある。

**検討した選択肢**:
1. **Location テーブル新設**: 販売先を独立したマスタとして管理
2. **DailyInventory に location カラム追加**: 販売先を文字列で記録

**選択したアプローチ**: Location テーブル新設

**理由**:
- 販売先の追加・編集・削除が容易
- 将来的な拡張（住所、営業時間、担当者など）に対応しやすい
- データ整合性（外部キー制約で参照整合性を保証）
- 販売先一覧の表示が高速

**トレードオフ**:
- メリット: 拡張性、データ整合性、管理容易性
- デメリット: テーブル数増加（+1）、JOIN クエリ増加

**設計詳細**:
- Location: id, name, deleted_at
- DailyInventory: location_id FK を追加
- Sale: location_id FK を追加
- ユニーク制約変更: (catalog_id, inventory_date) → (location_id, catalog_id, inventory_date)

---

### 決定10: DailyInventory のユニーク制約変更

**コンテキスト**: 販売先ごとに在庫を管理するため、DailyInventory のユニーク制約を変更する必要がある

**現行設計**: (catalog_id, inventory_date) がユニーク

**新設計**: (location_id, catalog_id, inventory_date) がユニーク

**理由**:
- 同じ日付・同じ商品でも、販売先ごとに異なる在庫数を管理可能
- 例: 市役所の日替わり弁当A（10個）と県庁の日替わり弁当A（5個）を別々に管理

**設計詳細**:
- インデックス名: idx_daily_inventories_location_catalog_date
- UNIQUE (location_id, catalog_id, inventory_date)
- location_id NOT NULL 制約を追加

---

### 決定11: AdditionalOrder への location_id 追加

**コンテキスト**: 追加発注も販売先ごとに管理すべきか検討

**選択したアプローチ**: AdditionalOrder に location_id FK を追加

**理由**:
- 追加発注は特定の販売先の在庫を補充するため、販売先と紐づける必要がある
- 追加発注履歴を販売先ごとに集計可能
- DailyInventory の在庫更新ロジックを統一

**設計詳細**:
- AdditionalOrder: location_id FK を追加
- location_id NOT NULL 制約を追加

---

## Discovery Phase 4 - 2026-01-05（Requirement 9 明確化）

### 決定12: Admin UI 管理機能の削除と認可機能の不要化

**コンテキスト**: Requirement 9 が更新され、Admin と Employee のユーザー管理に関する詳細が明確化された。

**変更内容**:
1. **Employee**: オーナーと販売員を一律で扱う業務ユーザー（機能的な区別なし）
2. **Admin**: システム開発者のみ（デバッグ・運用サポート用）
3. **認可機能（権限制御）は不要**: Employee と Admin は想定されるすべての機能を利用可能
4. **Admin の UI 管理機能は不要**: Rails console でのみ作成・編集・削除
5. **ログイン画面は共通**: Employee と Admin が同じログイン画面を使用

**設計への影響**:
- **AdminEmployeesController を削除**: Admin 用の CRUD UI は提供しない
- **認可ロジック不要**: Employee と Admin で機能アクセス制限なし
- **Rodauth 設定の簡略化**: 共通ログイン画面を使用（prefix 分離は不要の可能性）
- **Employee CRUD**: Admin のみが実行可能（現状維持）

**理由**:
- 現状は販売員（母）のみが利用想定のため、複雑な権限管理は不要
- Admin は開発者のみのため、Rails console での操作で十分
- システムのシンプル性を保ち、実装コストを削減

**トレードオフ**:
- メリット: シンプルな実装、開発コスト削減、保守容易性
- デメリット: Admin の UI がないため、非エンジニアが Admin を管理できない（将来的に追加可能）

**フォローアップ**: 将来的に Admin 管理 UI が必要になった場合は、Admin::EmployeesController を追加可能

---

### 決定13: Employee管理画面への認可制御の追加

**コンテキスト**: Requirement 9 が再更新され、Employee管理画面（CRUD）へのアクセスを Admin のみに制限する認可制御が必要になった。

**変更内容**:
1. **Employee管理画面へのアクセス制限**: Admin のみがアクセス可能、Employee がアクセスすると 403 エラー
2. **認可制御の実装**: EmployeesController に before_action フィルタで Admin 認証を実装
3. **Acceptance Criteria 追加**: AC 14-15 を追加（Employee のアクセス拒否、Admin のみアクセス許可）

**設計への影響**:
- **EmployeesController**: `before_action :require_admin_authentication` を追加
- **認可ヘルパー**: rodauth-rails の `rodauth(:admin).logged_in?` と `rodauth(:employee).logged_in?` で判定
- **エラーハンドリング**: Employee がアクセスすると `head :forbidden` で 403 エラー、未認証の場合は Admin ログインページにリダイレクト
- **テスト追加**: EmployeesController の認可制御テスト（Admin: 成功、Employee: 403、未認証: リダイレクト）

**理由**:
- Employee が誤って他の Employee を編集・削除するリスクを排除
- Admin のみが Employee 管理を行えるようにすることで、運用の安全性を確保
- rodauth-rails の公式機能（`logged_in?`, `require_account`）を活用することで、認証・認可ロジックを統一
- シンプルな認可制御で実装コストを最小化

**トレードオフ**:
- メリット: 安全性向上、誤操作防止、rodauth-rails の標準機能を活用、テスタビリティ向上
- デメリット: 認可ロジックの追加により若干の複雑性増加

**実装パターン（rodauth-rails 公式機能を使用）**:
```ruby
# app/controllers/employees_controller.rb
class EmployeesController < ApplicationController
  before_action :require_admin_authentication

  private

  def require_admin_authentication
    # Employee でログイン済みの場合は 403 エラー
    if rodauth(:employee).logged_in?
      head :forbidden
    else
      # Admin でログインしていない場合は Admin ログインページにリダイレクト
      rodauth(:admin).require_account
    end
  end
end
```

**参考資料**:
- [rodauth-rails - Requiring authentication](https://github.com/janko/rodauth-rails?tab=readme-ov-file#requiring-authentication)
- [rodauth-rails - Multiple configurations](https://github.com/janko/rodauth-rails?tab=readme-ov-file#multiple-configurations)

---

## Discovery Phase 5 - 2026-01-07（Requirement 13 明確化）

### 決定14: クーポン適用条件の明確化（quantity ベース）

**コンテキスト**: Requirement 13 の AC 2, 8 が更新され、クーポン適用条件が「ラインアイテム数」ではなく「弁当 quantity の合計」であることが明確化された。

**変更内容**:
- Coupon#applicable? と Coupon#max_applicable_quantity を quantity ベースに変更
- `.count` → `.sum { |item| item[:quantity] }`

**理由**:
- 例: 日替わりA 3個 + 日替わりB 2個 = 弁当5個 → クーポン最大5枚適用可能
- ラインアイテム数（2種類）ではなく、合計個数（5個）でカウントする
- ビジネス要件として「弁当1個につき1枚」の意味が「購入した弁当の合計個数につき1枚」であることが明確化

**影響範囲**:
- Coupon モデルのメソッド
- Sales::PriceCalculator の割引計算ロジック
- 関連するテストケース

**トレードオフ**:
- メリット: ビジネス要件に正確に準拠、ユーザーにとって直感的
- デメリット: なし（設計の明確化のみ）

---
