---
paths:
  - "app/frontend/stylesheets/**/*"
  - "app/views/**/*"
---

# CSS Framework ガイドライン

## スタイリング方針

1. **daisyUI コンポーネントを優先**: ボタン、カード、フォーム要素などは daisyUI のクラスを使用
2. **Tailwind CSS で補完**: daisyUI で対応できないレイアウトやカスタマイズは Tailwind ユーティリティクラスで対応
3. **カスタム CSS は最小限**: `application.tailwind.css` への追記は避ける

## プロジェクト設定

- **テーマ**: bumblebee（daisyUI）
- **フォント**: Noto Sans JP（本文）, Noto Sans Mono（コード）
- **設定ファイル**: `app/frontend/stylesheets/application.tailwind.css`

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
