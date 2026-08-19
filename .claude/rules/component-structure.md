---
paths:
  - "app/views/components/**/*.rb"
  - "app/views/components/**/*.erb"
---

# ViewComponent ディレクトリ構造ルール

[目的: フラットな構造による認知負荷の軽減とコンポーネントの見通しの良さの維持]

## 必須ルール

### コンポーネント内にコンポーネントをネストしない

コンポーネントディレクトリ内に別のコンポーネントディレクトリを作成しないこと。
最大2階層（名前空間/コンポーネント名）までとする。

```
# 正しい例（フラット構造）
app/views/components/
├── locations/
│   ├── list/
│   │   ├── component.rb
│   │   └── component.html.erb
│   ├── show/
│   │   ├── component.rb
│   │   └── component.html.erb
│   ├── basic_info/
│   │   ├── component.rb
│   │   └── component.html.erb
│   └── basic_info_form/
│       ├── component.rb
│       └── component.html.erb
└── catalogs/
    ├── list/
    └── show/

# 誤り（深いネスト）
app/views/components/
└── locations/
    └── show/
        ├── component.rb
        └── basic_info/           # NG: 3階層目
            ├── component.rb
            └── form/             # NG: 4階層目
                └── component.rb
```

## 命名規則

### 関連コンポーネントの命名

同じリソースに関連するコンポーネントは、同じ名前空間内でフラットに配置する。
フォームや編集バリアントは `_form` サフィックスを使用する。

| 用途 | 命名パターン | 例 |
|------|-------------|-----|
| 一覧表示 | `{resource}/list` | `locations/list` |
| 詳細表示 | `{resource}/show` | `locations/show` |
| セクション表示 | `{resource}/{section_name}` | `locations/basic_info` |
| セクション編集 | `{resource}/{section_name}_form` | `locations/basic_info_form` |
| カード表示 | `{resource}/card` | `locations/card` |
| 状態バッジ | `{resource}/status_badge` | `locations/status_badge` |
| カード上の状態オーバーレイ | `overlay_badge` | — |

状態を色付きバッジで見せるコンポーネントは、リソースごとに `{resource}/status_badge` を作る。
状態の由来（enum カラムか、関連の有無からの導出か）と i18n の置き場所がリソースごとに違うため、
1 つに統合せず名前空間で並べる。

カードの上にバッジを重ねたい場合は `overlay_badge` を使う。これはリソースに依存せず、
重ねる位置だけを担当し、バッジ本体は `badge` スロットで受け取る。
ラベルを文字列で渡さないこと。渡すと `{resource}/status_badge` と同じ文言を二重に定義することになる。

```erb
<%= component "overlay_badge", overlaid: discontinued? do |overlay| %>
  <% overlay.with_badge do %>
    <%= component "catalogs/status_badge", catalog: catalog %>
  <% end %>
  <%# カード本体 %>
<% end %>
```

### モジュール構造

ディレクトリ構造に対応するモジュール構造を維持する。

```ruby
# locations/list/component.rb
module Locations
  module List
    class Component < Application::Component
    end
  end
end

# locations/basic_info/component.rb
module Locations
  module BasicInfo
    class Component < Application::Component
    end
  end
end

# locations/basic_info_form/component.rb
module Locations
  module BasicInfoForm
    class Component < Application::Component
    end
  end
end
```

## 理由

1. **認知負荷の軽減**: フラットな構造により、コンポーネントの場所を即座に把握できる
2. **参照の簡潔さ**: `Locations::BasicInfo::Component` のような短い参照が可能
3. **一覧性の向上**: 同じ名前空間のコンポーネントが一目で確認できる
4. **リファクタリングの容易さ**: ネストが浅いため移動や名前変更が簡単

## コンポーネント間の参照

関連コンポーネント間で定数を参照する場合は、完全修飾名を使用する。

```ruby
# locations/basic_info_form/component.rb
def frame_id
  Locations::BasicInfo::Component::FRAME_ID
end
```

## ビューからの呼び出し

`component` ヘルパーを使用してフラットなパスで呼び出す。

```erb
<%# 正しい例 %>
<%= component "locations/list", locations: @locations %>
<%= component "locations/basic_info", location: @location %>
<%= component "locations/basic_info_form", location: @location %>

<%# 誤り（深いパス） %>
<%= component "locations/show/basic_info", location: @location %>
<%= component "locations/show/basic_info/form", location: @location %>
```

---
_コンポーネントは最大2階層までのフラット構造を維持すること。深いネストが必要な場合は設計を見直す。_
