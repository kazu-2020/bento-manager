# Implementation Gap Analysis: sales-tracking-pos

## 分析概要

**分析対象**: 販売追跡・簡易POSシステム（sales-tracking-pos）の実装ギャップ
**コードベース状態**: ほぼグリーンフィールド（基本的なRails 8.1 + Hotwireスケルトンのみ）
**分析日**: 2026-01-03

### 主要な発見

- **既存資産**: Rails 8.1スケルトン、Hotwire（Turbo + Stimulus）、Tailwind CSS v4、Vite統合が完了
- **ギャップ**: データモデル、認証機能、ビジネスロジック、UI/UXコンポーネントのすべてが未実装
- **推奨アプローチ**: 新規作成主体（Option B: Create New Components）、Rails規約に則った段階的実装
- **実装規模**: 中〜大規模（L-XL: 2-3週間程度）
- **リスクレベル**: 中（確立されたパターンを使用するが、オフライン同期とデータ分析機能に技術的課題あり）

---

## 1. 現状調査（Current State Investigation）

### 1.1 既存資産の棚卸し

#### ディレクトリ構成
```
app/
├── controllers/
│   ├── application_controller.rb  # 基底コントローラ
│   └── home_controller.rb        # サンプルコントローラ（index のみ）
├── models/
│   └── application_record.rb     # 基底モデル（ActiveRecord抽象クラス）
├── views/
│   ├── home/index.html.erb       # サンプルビュー（Tailwind テスト用）
│   └── layouts/application.html.erb
├── frontend/
│   ├── controllers/
│   │   ├── hello_controller.js  # サンプルStimulusコントローラ
│   │   ├── application.js
│   │   └── index.js
│   ├── entrypoints/application.js
│   └── stylesheets/application.tailwind.css
└── (helpers/, jobs/, mailers/ は空)
```

#### データベース
- **スキーマ**: 空（`ActiveRecord::Schema[8.1].define(version: 0)`）
- **マイグレーション**: なし
- **マルチDB設定**: config/database.yml に primary, cache, queue, cable の設定済み

#### 認証機能
- **現状**: 未実装
- **Gemfile**: bcrypt がコメントアウト（`# gem "bcrypt", "~> 3.1.7"`）
- **Devise等**: 未導入

#### フロントエンド
- **Stimulus**: hello_controller.js サンプルのみ
- **Turbo**: 設定済みだが、Turbo Frames/Streams の実装例なし
- **Tailwind CSS**: 動作確認済み（v4.1.18）
- **グラフライブラリ**: 未導入（Requirement 8 で必要）

#### 既存パターン
- Rails 8.1 規約準拠
- Fat Models, Skinny Controllers の原則（steering/structure.md）
- Stimulus Controllers per Feature（steering/structure.md）
- Server-Side Rendering優先（steering/tech.md）

### 1.2 技術スタック確認

| カテゴリ | 技術 | ステータス | 備考 |
|---------|------|-----------|------|
| バックエンド | Rails 8.1.1 | ✅ 導入済 | - |
| データベース | SQLite3 | ✅ 導入済 | マルチDB設定済 |
| 認証 | bcrypt / Devise | ❌ 未導入 | Gemfileにコメントアウト |
| フロントエンド | Turbo + Stimulus | ✅ 導入済 | 実装例なし |
| スタイリング | Tailwind CSS v4 | ✅ 導入済 | - |
| ビルドツール | Vite 7.3.0 | ✅ 導入済 | HMR動作確認済 |
| グラフ描画 | Chart.js / ApexCharts | ❌ 未導入 | Requirement 8 で必要 |
| オフライン対応 | Service Worker / localStorage | ❌ 未実装 | Requirement 11 で必要 |
| テスト | Minitest | ✅ 導入済 | テストコードなし |

---

## 2. 要件実現性分析（Requirements Feasibility Analysis）

### 2.1 技術要素の抽出

#### データモデル（新規作成が必要）

| モデル名 | 責務 | 関連要件 | ステータス |
|---------|------|---------|-----------|
| `BentoItem` | 弁当商品マスタ（商品名、価格、カテゴリ） | Req 1 | ❌ 未実装 |
| `DailyInventory` | 販売日の初期在庫（日付、弁当商品、初期数量） | Req 2 | ❌ 未実装 |
| `Sale` | 販売記録（販売日時、顧客区分、合計金額） | Req 3 | ❌ 未実装 |
| `SaleItem` | 販売明細（販売ID、弁当商品、数量、小計） | Req 3 | ❌ 未実装 |
| `AdditionalOrder` | 追加発注記録（日付、弁当商品、追加数量、発注時刻） | Req 5 | ❌ 未実装 |
| `Admin` | システム管理者（メール、パスワード） | Req 9 | ❌ 未実装 |
| `Employee` | 従業員（メール、パスワード、氏名） | Req 9 | ❌ 未実装 |

**リレーション概要**:
- `BentoItem` 1:N `DailyInventory`
- `BentoItem` 1:N `SaleItem`
- `BentoItem` 1:N `AdditionalOrder`
- `Sale` 1:N `SaleItem`
- `DailyInventory` N:1 販売日（日付で集約）

#### API/サービス（新規作成が必要）

| サービス/コントローラ | 責務 | 関連要件 | ステータス |
|---------------------|------|---------|-----------|
| `BentoItemsController` | 弁当商品のCRUD | Req 1 | ❌ 未実装 |
| `DailyInventoriesController` | 在庫登録・一覧 | Req 2 | ❌ 未実装 |
| `SalesController` | 販売記録・POS機能 | Req 3, 4 | ❌ 未実装 |
| `AdditionalOrdersController` | 追加発注記録 | Req 5 | ❌ 未実装 |
| `SalesAnalyticsService` | 販売データ分析・予測ロジック | Req 6 | ❌ 未実装 |
| `ReportsController` | 日次レポート・可視化 | Req 7, 8 | ❌ 未実装 |
| `EmployeesController` | 従業員登録・管理（システム管理者専用） | Req 9 | ❌ 未実装 |
| `ApplicationController` | 認証チェック、管理者権限チェック（before_action） | Req 9 | 🔶 拡張必要 |

#### UI/コンポーネント（新規作成が必要）

| コンポーネント | 技術 | 関連要件 | ステータス |
|--------------|------|---------|-----------|
| 弁当商品一覧・フォーム | ERB + Turbo Frames | Req 1 | ❌ 未実装 |
| 在庫登録フォーム | ERB + Stimulus | Req 2 | ❌ 未実装 |
| POS販売画面（スマホ最適化） | ERB + Stimulus + Turbo Streams | Req 3, 4 | ❌ 未実装 |
| 在庫リアルタイム表示 | Turbo Streams | Req 4 | ❌ 未実装 |
| 追加発注支援UI | ERB + Stimulus | Req 5, 6 | ❌ 未実装 |
| 日次レポート・ダッシュボード | ERB + Chart.js/ApexCharts | Req 7, 8 | ❌ 未実装 |
| ログイン画面 | ERB + Turbo | Req 9 | ❌ 未実装 |
| レスポンシブレイアウト | Tailwind CSS | Req 10 | 🔶 基盤あり |
| オフライン同期UI | Stimulus + Service Worker | Req 11 | ❌ 未実装 |

#### ビジネスロジック

| ロジック | 実装場所候補 | 関連要件 | 複雑度 |
|---------|-------------|---------|-------|
| 在庫減算（販売時） | `Sale` モデル（after_create callback） | Req 3 | 低 |
| 在庫加算（追加発注時） | `AdditionalOrder` モデル（after_create callback） | Req 5 | 低 |
| 販売予測アルゴリズム | `SalesAnalyticsService` | Req 6 | 高 |
| グラフデータ集計 | `ReportsController` または `ReportService` | Req 7, 8 | 中 |
| 管理者権限チェック | `ApplicationController` + 手動実装（Adminモデル判定） | Req 9 | 低 |
| 楽観的ロック/悲観的ロック | `Sale` モデル（トランザクション） | Req 12 | 中 |

#### 非機能要件

| 要件 | 技術選択肢 | ステータス | 備考 |
|------|----------|-----------|------|
| 認証 | Rodauth-Rails / Devise / bcrypt + has_secure_password | ✅ Rodauth-Rails | セキュリティ重視、段階的機能追加が容易 |
| 権限管理 | モデル分離（Admin/Employee） | ✅ モデル分離 | ドメインが異なるため、STIではなく別テーブルで管理 |
| グラフ描画 | Chart.js / ApexCharts / Chartkick | ❌ 選択必要 | Chart.jsが軽量、Chartkickが Rails親和性高 |
| オフライン同期 | Service Worker + localStorage + sync API | ❌ 未実装 | 技術的難易度高 |
| キャッシュ | Solid Cache（導入済） | ✅ 利用可能 | Requirement 12 |
| ロック制御 | ActiveRecord::Locking | ✅ 利用可能 | Requirement 12 |
| インデックス | マイグレーションで設定 | ❌ 未設定 | Requirement 12 |

### 2.2 ギャップと制約の特定

#### ギャップ（Missing Capabilities）

| ID | ギャップ内容 | 影響範囲 | 優先度 |
|----|------------|---------|-------|
| G1 | データモデル全体が未実装 | 全要件 | 高 |
| G2 | 認証・権限管理機能が未実装 | Req 9 | 高 |
| G3 | 販売予測ロジックが未実装 | Req 6 | 中 |
| G4 | グラフ描画ライブラリが未導入 | Req 8 | 中 |
| G5 | オフライン同期機構が未実装 | Req 11 | 高（技術的難易度大） |
| G6 | Turbo Frames/Streams の実装例なし | Req 3, 4 | 低（学習曲線） |
| G7 | スマホ最適化UIの実装なし | Req 3, 10 | 中 |

#### 調査が必要な項目（Research Needed）

| ID | 調査項目 | 理由 | 優先度 |
|----|---------|------|-------|
| R1 | オフライン同期の実装方式 | Service Worker + localStorage + バックグラウンド同期の詳細設計が必要 | 高 |
| R2 | 販売予測アルゴリズムの選択 | 統計的手法（移動平均、線形回帰、時系列分析）の比較検討が必要 | 中 |
| R3 | グラフライブラリの選定 | Chart.js vs ApexCharts vs Chartkick の機能・パフォーマンス比較 | 低 |
| R4 | 権限管理ライブラリの選定 | Pundit vs CanCanCan vs 手動実装のトレードオフ | 低 |
| R5 | 楽観的/悲観的ロックの選択 | 在庫同時更新のユースケースに応じた選択 | 中 |

#### 既存アーキテクチャの制約（Constraints）

| 制約 | 内容 | 影響 |
|------|------|------|
| C1 | SQLite3使用（開発環境） | 本番環境での同時接続数に制約あり（検討必要） |
| C2 | Hotwire優先（Rails規約） | 重いJavaScriptフレームワーク（React/Vue）は使用不可 |
| C3 | Fat Models, Skinny Controllers | ビジネスロジックはモデルまたはサービスオブジェクトに配置 |
| C4 | Server-Side Rendering優先 | クライアント側でのテンプレート生成は最小限に |

### 2.3 複雑度シグナル

| 要件領域 | 複雑度 | 理由 |
|---------|-------|------|
| Req 1-2: マスタ・在庫管理 | **単純（CRUD）** | 標準的なRails CRUDパターン |
| Req 3-4: POS・在庫確認 | **中（ワークフロー）** | Turbo Streams でのリアルタイム更新、トランザクション制御 |
| Req 5: 追加発注 | **単純（CRUD + ビジネスルール）** | 在庫加算ロジック、弁当種別制限 |
| Req 6: 販売予測 | **高（アルゴリズム）** | 統計的推定、過去データ集計、エッジケース処理 |
| Req 7-8: レポート・可視化 | **中（集計 + 外部統合）** | SQLクエリ最適化、グラフライブラリ統合 |
| Req 9: 認証・従業員管理 | **低〜中（セキュリティ）** | Rodauth統合、Admin/Employeeモデル分離 |
| Req 10: レスポンシブデザイン | **低（CSS）** | Tailwind CSSで実現可能 |
| Req 11: オフライン対応 | **高（外部統合 + 同期）** | Service Worker、データ同期、競合解決 |
| Req 12: データ整合性 | **中（パフォーマンス）** | ロック制御、キャッシュ、インデックス設計 |

---

## 3. 実装アプローチの選択肢（Implementation Approach Options）

### Option A: 既存コンポーネントの拡張（Extend Existing Components）

**適用可能性**: ❌ 不適用

**理由**:
- 既存のコントローラ（`HomeController`）やモデルは空に近く、拡張対象がほぼ存在しない
- グリーンフィールド状態のため、拡張よりも新規作成が適切

**該当する可能性のある箇所**:
- `ApplicationController`: 認証・権限チェックのbefore_actionを追加（軽微な拡張）

**トレードオフ**:
- ✅ 最小限のファイル追加
- ❌ 既存ファイルが肥大化するリスク（今回は該当せず）

---

### Option B: 新規コンポーネントの作成（Create New Components）★ 推奨

**適用可能性**: ✅ 最適

**理由**:
- 既存資産がほぼ空であり、ドメインロジック全体を新規作成する必要がある
- Rails規約に則った標準的なMVC構造を構築できる
- テスト容易性、保守性が高い

#### 新規作成が必要なコンポーネント

##### モデル（`app/models/`）
```ruby
# 弁当商品マスタ
app/models/bento_item.rb
  - 属性: name, price, category (enum: daily_a, daily_b, other)
  - バリデーション: name presence, price numericality, category inclusion
  - 論理削除: deleted_at (Paranoia gem または手動実装)
  - リレーション: has_many :daily_inventories, :sale_items, :additional_orders

# 日次在庫
app/models/daily_inventory.rb
  - 属性: sale_date, bento_item_id, initial_quantity
  - バリデーション: uniqueness of [sale_date, bento_item_id]
  - メソッド: current_stock (初期在庫 + 追加発注 - 販売数)

# 販売記録
app/models/sale.rb
  - 属性: sold_at, customer_type (enum: staff, general), total_amount
  - リレーション: has_many :sale_items
  - after_create: 在庫減算（SaleItem経由）
  - トランザクション制御: with_lock または transaction

# 販売明細
app/models/sale_item.rb
  - 属性: sale_id, bento_item_id, quantity, subtotal
  - バリデーション: quantity > 0, subtotal = bento_item.price * quantity
  - after_create: DailyInventory.current_stock を減算

# 追加発注
app/models/additional_order.rb
  - 属性: order_date, bento_item_id, quantity, ordered_at
  - バリデーション: bento_item.category == :daily_a
  - after_create: DailyInventory.current_stock を加算

# システム管理者
app/models/admin.rb
  - 属性: email, password_hash
  - Rodauth統合（Rodauthがパスワードハッシュを管理）
  - バリデーション: email uniqueness, presence

# 従業員
app/models/employee.rb
  - 属性: email, password_hash, name
  - Rodauth統合（Rodauthがパスワードハッシュを管理）
  - バリデーション: email uniqueness, presence, name presence
```

##### コントローラ（`app/controllers/`）
```ruby
app/controllers/bento_items_controller.rb        # Req 1: CRUD
app/controllers/daily_inventories_controller.rb  # Req 2: 在庫登録・一覧
app/controllers/sales_controller.rb              # Req 3, 4: POS機能
app/controllers/additional_orders_controller.rb  # Req 5: 追加発注
app/controllers/reports_controller.rb            # Req 7, 8: レポート・ダッシュボード
app/controllers/rodauth_controller.rb            # Req 9: Rodauthエンドポイント（自動生成）
app/controllers/employees_controller.rb          # Req 9: 従業員管理（システム管理者専用）
```

##### サービスオブジェクト（`app/services/`）
```ruby
app/services/sales_analytics_service.rb
  - メソッド:
    - recommend_additional_order(sale_date, current_time)
      - 過去の同一曜日・時間帯データを集計
      - 平均値・標準偏差を計算（4週間以上のデータがある場合）
      - 予測販売数 = 現在在庫 - 推奨追加発注数
```

##### ビュー（`app/views/`）
```ruby
app/views/bento_items/          # index, new, edit, _form.html.erb
app/views/daily_inventories/    # index, new, _form.html.erb
app/views/sales/                # new (POS画面), show (領収書), _inventory_status.html.erb
app/views/additional_orders/    # new, index
app/views/reports/              # dashboard.html.erb, daily_report.html.erb
app/views/rodauth/              # Rodauth views（ログイン、パスワードリセット等）
app/views/employees/            # index, new, edit, _form.html.erb（従業員管理）
```

##### Stimulusコントローラ（`app/frontend/controllers/`）
```javascript
app/frontend/controllers/pos_controller.js
  - 機能: 商品選択、数量変更、小計・合計計算、在庫チェック
  - ターゲット: 商品リスト、数量入力、合計金額表示

app/frontend/controllers/inventory_controller.js
  - 機能: リアルタイム在庫表示（Turbo Streams経由）
  - ターゲット: 在庫数表示、在庫ゼロ警告

app/frontend/controllers/chart_controller.js
  - 機能: Chart.js を使ったグラフ描画
  - ターゲット: canvas要素

app/frontend/controllers/offline_sync_controller.js
  - 機能: オフライン検知、localStorage保存、バックグラウンド同期
  - ターゲット: フォーム、同期ステータス表示
```

##### マイグレーション（`db/migrate/`）
```ruby
YYYYMMDDHHMMSS_create_bento_items.rb
YYYYMMDDHHMMSS_create_daily_inventories.rb
YYYYMMDDHHMMSS_create_sales.rb
YYYYMMDDHHMMSS_create_sale_items.rb
YYYYMMDDHHMMSS_create_additional_orders.rb
YYYYMMDDHHMMSS_create_admins.rb
YYYYMMDDHHMMSS_create_employees.rb
YYYYMMDDHHMMSS_add_indexes.rb  # sale_date, bento_item_id, sold_at にインデックス
```

#### 統合ポイント

| 統合先 | 統合内容 | 方法 |
|-------|---------|------|
| `ApplicationController` | 認証チェック | `before_action :require_login`（Rodauth提供） |
| `ApplicationController` | 管理者権限チェック | `before_action :require_admin, only: [:employees管理アクション]` |
| `config/initializers/rodauth.rb` | Rodauth設定 | Rodauth feature設定（login, logout, password hash等） |
| `config/routes.rb` | ルーティング追加 | `resources :bento_items, :sales, etc.` |
| `app/frontend/entrypoints/application.js` | Stimulusコントローラ自動登録 | Viteが自動処理（設定済み） |
| `package.json` | Chart.js 追加 | `npm install chart.js` |

#### 責務境界

| コンポーネント | 責務 | 責務外 |
|--------------|------|-------|
| `BentoItem` | 商品情報の管理、論理削除 | 在庫計算、販売ロジック |
| `DailyInventory` | 日次在庫の管理、現在在庫計算 | 販売記録、予測ロジック |
| `Sale` / `SaleItem` | 販売記録、在庫減算 | 在庫登録、予測ロジック |
| `SalesAnalyticsService` | 販売予測、データ集計 | 在庫更新、販売記録 |
| `Admin` | システム管理者情報管理 | 認証処理（Rodauthが担当）、業務ロジック |
| `Employee` | 従業員情報管理 | 認証処理（Rodauthが担当） |
| `ApplicationController` | 認証・管理者権限チェック | ビジネスロジック |

**トレードオフ**:
- ✅ 明確な責務分離
- ✅ テスト容易性が高い
- ✅ Rails規約に準拠
- ❌ ファイル数が増加（約30-40ファイル）
- ❌ インターフェース設計が必要

---

### Option C: ハイブリッドアプローチ（Hybrid Approach）

**適用可能性**: 🔶 部分的に適用

**組み合わせ戦略**:

1. **Phase 1: コア機能実装（Option B）**
   - データモデル、CRUD、認証を新規作成
   - スコープ: Req 1, 2, 3, 5, 9

2. **Phase 2: 高度な機能追加（Option B）**
   - 販売予測、グラフ可視化を新規作成
   - スコープ: Req 6, 7, 8

3. **Phase 3: オフライン対応（Option B + 段階的ロールアウト）**
   - Service Worker 実装、フィーチャーフラグで段階展開
   - スコープ: Req 11

**段階的実装の利点**:
- フィードバックループを早期に確立
- 複雑な機能（予測、オフライン）をリスク分離

**リスク軽減**:
- Phase 1 完了時点でMVPとしてリリース可能
- オフライン対応はフィーチャーフラグ（環境変数）で制御

**トレードオフ**:
- ✅ 段階的な価値提供
- ✅ リスクの分散
- ❌ 全体スケジュールが長期化
- ❌ 各フェーズ間の整合性管理が必要

---

## 4. 実装の複雑度とリスク（Implementation Complexity & Risk）

### 実装規模（Effort）

**総合評価: L-XL（大規模、2-3週間）**

| フェーズ | スコープ | 工数 | 理由 |
|---------|---------|------|------|
| Phase 1: 基盤構築 | データモデル、マイグレーション、認証 | M（5-7日） | 標準的なRails開発、既知のパターン |
| Phase 2: コア機能 | CRUD、POS、在庫管理 | M（5-7日） | Turbo Streams学習曲線、UI実装 |
| Phase 3: 分析・可視化 | 販売予測、グラフ、レポート | L（1-2週） | アルゴリズム設計、Chart.js統合、クエリ最適化 |
| Phase 4: オフライン対応 | Service Worker、同期機構 | L（1-2週） | 技術的難易度高、競合解決ロジック |
| Phase 5: テスト・調整 | 統合テスト、パフォーマンス調整 | M（3-5日） | エンドツーエンドテスト、キャッシュ最適化 |

**並行作業の可能性**:
- Phase 1-2 は順次実施必須
- Phase 3-4 は部分的に並行可能（UI実装者とロジック実装者が分かれる場合）

### リスクレベル（Risk）

**総合評価: 中（Medium）**

| リスク項目 | レベル | 理由 | 軽減策 |
|-----------|-------|------|-------|
| 技術スタック学習 | 低 | Rails, Hotwire は確立された技術 | 公式ドキュメント、サンプルアプリ参照 |
| データモデル設計 | 低 | シンプルなリレーショナルモデル | ER図作成、ピアレビュー |
| 販売予測アルゴリズム | 中 | 統計的手法の選択、エッジケース対応 | プロトタイプで検証、段階的精度向上 |
| オフライン同期 | 高 | Service Worker、競合解決、データ整合性 | 調査フェーズを設ける、フィーチャーフラグで制御 |
| パフォーマンス | 中 | SQLite3の同時接続制限、クエリ最適化 | インデックス設計、キャッシュ戦略、本番環境でPostgreSQL検討 |
| セキュリティ | 中 | 認証・認可の適切な実装 | bcrypt使用、CSRF保護（Rails標準）、権限チェック徹底 |
| スマホUI/UX | 低 | Tailwind CSSで実現可能 | モバイルファーストデザイン、実機テスト |

**ハイリスク項目の詳細**:

#### R1: オフライン同期（高リスク）
- **課題**:
  - Service Workerのブラウザ互換性
  - ネットワーク復旧時の競合解決（同一在庫への複数更新）
  - localStorageの容量制限
- **軽減策**:
  - Phase 4 として独立実装、MVP（Phase 1-3）とは切り離す
  - 競合時は「最後の書き込みが勝つ」または「手動マージUI」を提供
  - Progressive Enhancement: オフライン機能は段階的に有効化

#### R2: 販売予測アルゴリズム（中リスク）
- **課題**:
  - 過去データ不足時の挙動
  - 外れ値（特別イベント等）の扱い
  - 統計的手法の選択（移動平均 vs 線形回帰 vs ARIMA）
- **軽減策**:
  - 初期は単純移動平均でプロトタイプ
  - データが蓄積された後、より高度な手法に移行
  - 「過去データ不足」時は警告を表示し、手動判断を促す

---

## 5. 推奨事項（Recommendations for Design Phase）

### 5.1 推奨アプローチ

**Option B: 新規コンポーネントの作成（段階的実装）**

**理由**:
1. グリーンフィールド状態であり、既存資産の拡張対象がほぼ存在しない
2. Rails規約に則った標準的なMVC構造を構築できる
3. テスト容易性、保守性が高い
4. フェーズ分割により、早期フィードバックとリスク分散が可能

**段階的実装順序**:
1. **Phase 1: 基盤（Week 1）**: データモデル、認証、基本CRUD
2. **Phase 2: コア業務（Week 2）**: POS機能、在庫管理、追加発注
3. **Phase 3: 分析・可視化（Week 3）**: 販売予測、グラフ、レポート
4. **Phase 4: オフライン対応（Week 4）**: Service Worker、同期機構（オプション）

### 5.2 重要な設計上の決定事項

| ID | 決定事項 | 選択肢 | 推奨 | 理由 |
|----|---------|-------|------|------|
| D1 | 認証方式 | Rodauth-Rails / Devise / bcrypt | **Rodauth-Rails** | セキュリティ重視、段階的機能拡張が容易、将来の拡張性 |
| D2 | 権限管理 | モデル分離（Admin/Employee） | **モデル分離** | ドメインが異なる、将来の拡張性を考慮してSTIではなく別テーブル |
| D3 | グラフライブラリ | Chart.js / ApexCharts / Chartkick | **Chartkick + Chart.js** | Rails親和性が高く、設定が簡潔 |
| D4 | 論理削除 | Paranoia gem / 手動実装 | **手動実装（deleted_at）** | シンプルな要件、gem不要 |
| D5 | 在庫ロック | 楽観的ロック / 悲観的ロック | **楽観的ロック** | 競合頻度が低い、パフォーマンス優先 |
| D6 | オフライン同期 | Service Worker + localStorage / PWA | **Service Worker** | ネイティブアプリ不要、段階的実装可能 |
| D7 | 販売予測初期実装 | 移動平均 / 線形回帰 / ARIMA | **移動平均** | シンプル、データ不足時も動作、後で拡張可能 |

### 5.3 設計フェーズで深掘りすべき調査項目

#### 高優先度（Phase 1-2 で必要）

1. **認証フロー設計（Req 9）**
   - Rodauth統合（login, logout, remember機能）
   - Admin/Employee 2つのRodauth設定（複数アカウントタイプ対応）
   - 従業員登録フローの実装（システム管理者がメアド・パスワード・氏名を入力）
   - 管理者権限チェックの実装（current_admin判定）

2. **在庫更新トランザクション設計（Req 3, 5, 12）**
   - 楽観的ロック（`lock_version` カラム）の実装詳細
   - 販売記録と在庫減算の原子性保証
   - エラーハンドリング（在庫不足時のロールバック）

3. **Turbo Streams による在庫リアルタイム更新（Req 4）**
   - ブロードキャスト対象の設計（全ユーザー？販売員のみ？）
   - Turbo Streams の送信タイミング（after_commit）
   - ネットワーク遅延時のUX

#### 中優先度（Phase 3 で必要）

4. **販売予測アルゴリズムのプロトタイプ（Req 6）**
   - 移動平均の期間（4週間？8週間？）
   - 曜日・時間帯の区分（1時間単位？30分単位？）
   - 標準偏差を用いた信頼区間の計算方法
   - エッジケース: データ不足、祝日、特別イベント

5. **グラフ描画のデータ取得最適化（Req 8）**
   - SQLクエリ設計（GROUP BY, DATE関数）
   - キャッシュ戦略（Solid Cache使用）
   - Chart.js のデータ形式への変換

#### 低優先度（Phase 4、またはMVP後）

6. **オフライン同期の詳細設計（Req 11）**
   - Service Worker のキャッシュ戦略（Cache-First？Network-First？）
   - localStorage のデータ構造（販売記録の一時保存形式）
   - 同期APIの設計（POST `/api/sync` エンドポイント）
   - 競合解決ロジック（Last-Write-Wins？Manual Merge？）

7. **本番環境のデータベース選定**
   - SQLite3 の同時接続数上限の検証
   - PostgreSQL への移行タイミング（ユーザー数が増えた場合）

### 5.4 技術スパイク（調査・検証）の提案

| スパイクID | 内容 | 目的 | 所要時間 |
|-----------|------|------|---------|
| S1 | Turbo Streams 動作検証 | 在庫リアルタイム更新の実現可能性確認 | 2-4時間 |
| S2 | Chart.js + Rails 統合 | グラフ描画の実装パターン確認 | 2-3時間 |
| S3 | 販売予測アルゴリズム試作 | 移動平均による推奨数計算のロジック検証 | 4-6時間 |
| S4 | Service Worker + localStorage 検証 | オフライン販売記録の実現可能性確認 | 6-8時間 |
| S5 | 楽観的ロック動作確認 | 在庫同時更新の競合制御検証 | 2-3時間 |

**推奨実施順序**: S1 → S5 → S2 → S3 → S4

---

## 6. まとめ

### 6.1 ギャップ分析の結論

| 項目 | 結論 |
|------|------|
| **現状** | ほぼグリーンフィールド、Rails 8.1 + Hotwire + Tailwind CSS の基盤のみ |
| **ギャップ** | データモデル、ビジネスロジック、UI/UX のすべてが未実装 |
| **推奨アプローチ** | Option B（新規コンポーネント作成）+ 段階的実装（4フェーズ） |
| **実装規模** | L-XL（2-3週間、フルタイム想定） |
| **リスクレベル** | 中（オフライン同期が高リスク、その他は中〜低リスク） |
| **重要決定事項** | 認証（bcrypt）、権限（手動）、グラフ（Chartkick）、ロック（楽観的）、予測（移動平均） |

### 6.2 次フェーズへの引き継ぎ事項

**設計フェーズで決定すべき内容**:
1. データモデルの詳細設計（ER図、バリデーション）
2. API設計（RESTfulルーティング、JSONレスポンス形式）
3. 画面遷移図（ワイヤーフレーム）
4. 販売予測アルゴリズムのプロトタイプ
5. オフライン同期の技術選定と設計
6. テスト戦略（単体テスト、統合テスト、E2Eテスト）

**技術調査が必要な項目**:
- Turbo Streams のブロードキャスト設計
- Service Worker のキャッシュ戦略
- 販売予測の統計的手法（移動平均の詳細）

**リスク軽減のための提案**:
- オフライン対応はMVP後に実装（Phase 4）
- 販売予測は単純移動平均から開始、段階的に高度化
- フィーチャーフラグで段階的ロールアウト

---

**分析完了日**: 2026-01-03
**次のステップ**: `/kiro:spec-design sales-tracking-pos` で技術設計フェーズへ進む
