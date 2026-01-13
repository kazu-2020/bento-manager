---
paths:
  - "app/controllers/**/*.rb"
  - "config/routes.rb"
---

# Rails コントローラー標準アクションルール

[目的: RESTful 設計の維持とコントローラーの責務の明確化]

## 必須ルール

### 標準7アクションのみを定義する

Rails コントローラーには以下の7つの標準アクションのみを定義すること。

| アクション | HTTP メソッド | 用途 |
|-----------|--------------|------|
| `index` | GET | リソース一覧の表示 |
| `show` | GET | 単一リソースの表示 |
| `new` | GET | 新規作成フォームの表示 |
| `create` | POST | リソースの作成 |
| `edit` | GET | 編集フォームの表示 |
| `update` | PATCH/PUT | リソースの更新 |
| `destroy` | DELETE | リソースの削除 |

```ruby
# 正しい例
class LocationsController < ApplicationController
  def index; end
  def show; end
  def new; end
  def create; end
  def edit; end
  def update; end
  def destroy; end
end

# 誤り（カスタムアクションの追加）
class LocationsController < ApplicationController
  def edit_basic_info; end  # NG: カスタムアクション
  def activate; end         # NG: カスタムアクション
  def search; end           # NG: カスタムアクション
end
```

## 理由

1. **RESTful 設計の維持**: Rails の規約に従うことで、一貫性のある API 設計が可能
2. **責務の分離**: カスタムアクションが必要な場合は、別のコントローラーに分離すべきサイン
3. **ルーティングの簡潔さ**: `resources` のみで完結し、カスタムルートが不要
4. **テストの容易さ**: 標準的なテストパターンが適用可能

## カスタムアクションが必要な場合の対処法

### パターン1: 別コントローラーに分離

```ruby
# Before（NG）
class OrdersController < ApplicationController
  def confirm; end
  def complete; end
end

# After（OK）
class Orders::ConfirmationsController < ApplicationController
  def new; end    # 確認画面の表示
  def create; end # 確定処理
end
```

### パターン2: Turbo Frame でリクエストを判別

```ruby
# 同一アクションで複数のレスポンス形式に対応
def edit
  if turbo_frame_request?
    render InlineEditFormComponent.new(resource: @resource)
  end
  # HTML リクエストの場合は暗黙的に edit.html.erb をレンダリング
end
```

### パターン3: ネストされたリソース

```ruby
# Before（NG）
resources :posts do
  member do
    post :publish
    post :unpublish
  end
end

# After（OK）
resources :posts do
  resource :publication, only: [:create, :destroy]
end
```

## ルーティング設計

```ruby
# 正しい例
resources :locations
resources :catalogs

# 誤り（カスタムルートの追加）
resources :locations do
  member do
    get :edit_basic_info  # NG
    post :activate        # NG
  end
  collection do
    get :search           # NG
  end
end
```

---
_コントローラーには標準7アクションのみを定義すること。カスタムアクションが必要な場合は設計を見直す。_
