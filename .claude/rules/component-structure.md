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

### 状態バッジ

状態を色付きバッジで見せるコンポーネントは、リソースごとに `{resource}/status_badge` を作る。
i18n の置き場所がリソースごとに違う（enum ラベルか sidecar か）ため、1 つに統合せず名前空間で並べる。

3 つの契約を守ること。守れば横に並べたとき同じ形になり、次の 1 つも迷わず書ける。

1. **状態の判定はモデルに置く。** バッジは `status:` でシンボルを受け取り、表示だけを担う。
   `status` カラムが無いリソースでも、`Catalog#status` や `Discount#status` のように
   モデル側に導出メソッドを生やす。呼び出し元やコンポーネントで判定しない
2. **色は `VARIANTS` ハッシュに完全なクラス名リテラルで持ち、`variant_class` で引く。**
   フォールバックは付けない（状態はモデルが返す有限集合なので、未知の値は落ちるべき）
3. **ラベルは `label` メソッドで解決する。** enum ラベルなら `I18n.t("enums.…")`、
   それ以外は sidecar の `t(".#{status}")`。置き場所の判断は `.claude/rules/i18n.md` に従う

### カード上の状態オーバーレイ

カードの上にバッジを重ねたい場合は `overlay_badge` を使う。リソースに依存せず、重ねる位置だけを担当する。

**バッジを渡すかどうかが、重ねるかどうかそのもの。** `badge` スロットを設定した場合だけ重なる。
「重ねるか」の真偽値引数は持たせない。持たせると「真だがバッジ無し」「偽だがバッジ有り」という
矛盾した状態が表現できてしまう。

ラベルを文字列で渡さないこと。渡すと `{resource}/status_badge` と同じ文言を二重に定義することになる。

```erb
<%= component "overlay_badge" do |overlay| %>
  <% if discontinued? %>
    <% overlay.with_badge do %>
      <%= component "catalogs/status_badge", status: catalog.status %>
    <% end %>
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
