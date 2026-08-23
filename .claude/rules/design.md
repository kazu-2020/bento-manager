---
paths:
  - "app/views/**/*"
  - "app/frontend/stylesheets/**/*"
---

# 視覚デザイン

UI を書く前に、リポジトリルートの [`DESIGN.md`](../../DESIGN.md) を読むこと。

`DESIGN.md` は Google Labs の [DESIGN.md 仕様](https://github.com/google-labs-code/design.md)（alpha）に沿った、
このアプリの視覚アイデンティティの定義である。「**いつどのトークンを選ぶか**」が書いてある。

特に次の 2 点は、コードを読むだけでは分からないので必ず参照すること。

- 色が「意味の層」と「役割の層」に分かれており、意味の層は入れ替えてはならないこと
- `error` 色が失敗ではなく「もう選べない状態」を意味すること

クラス名の書き方など Tailwind の技術的制約は [`css-framework.md`](./css-framework.md) にある。
