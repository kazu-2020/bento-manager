---
paths:
  - "app/frontend/stylesheets/**/*"
  - "app/views/**/*"
---

# CSS Framework ガイドライン

Tailwind CSS / daisyUI を使ううえでの**技術的な制約**をまとめる。

どのトークンをいつ選ぶか（色の意味、ボタンの使い分け、レイアウトの原則）は
リポジトリルートの [`DESIGN.md`](../../DESIGN.md) にある。そちらを先に読むこと。

## Context7 ドキュメント参照

スタイリング作業時は Context7 MCP を使用して最新ドキュメントを参照すること。

### 手順

1. `resolve-library-id` で library ID を取得
2. `query-docs` でドキュメントを検索

### Library ID

| ライブラリ | Context7 Library ID |
|-----------|---------------------|
| daisyUI | `/websites/daisyui` |
| Tailwind CSS | `/tailwindlabs/tailwindcss.com` |

### 使用例

```
// daisyUI のボタンコンポーネントを調べる場合
query-docs: libraryId="/websites/daisyui", query="button component variants"

// Tailwind CSS の flexbox を調べる場合
query-docs: libraryId="/tailwindlabs/tailwindcss.com", query="flexbox utilities"
```

## Tailwind CSS クラス名の注意事項

Tailwind CSS v4 はビルド時にソースファイルを**静的解析**してクラス名を検出する。文字列補間や動的生成されたクラス名は検出できない。

### 禁止パターン

文字列補間でクラス名を組み立ててはならない:

```ruby
# NG: Tailwind が検出できない
"alert-#{type}"
"bg-#{color}-500"
"text-#{size}"
```

```erb
<!-- NG -->
<div class="bg-<%= color %>-500">
```

### 推奨パターン

完全なクラス名文字列をソースコード上にリテラルとして記述する:

```ruby
# OK: 定数ハッシュでマッピング
TYPE_CLASSES = {
  success: "alert-success",
  error: "alert-error",
}.freeze

def alert_class
  TYPE_CLASSES[type]
end
```

```ruby
# OK: 条件分岐で完全なクラス名を返す
case type
when :success then "alert-success"
when :error   then "alert-error"
end
```

### 原則

- クラス名は**常に完全な文字列リテラル**としてソースに存在させる
- 文字列補間（`"prefix-#{var}"`）、`"#{prefix}-suffix"` は使わない
- ハッシュマッピング、case 文、三項演算子など、完全なクラス名がリテラルとして現れる方法を使う
