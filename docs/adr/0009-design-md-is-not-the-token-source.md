# ADR-0009: DESIGN.md をデザイントークンの出典にしない

- **状態**: 承認
- **日付**: 2026-08-23
- **関連 PR**: [#422](https://github.com/kazu-2020/bento-manager/pull/422)

## 背景

UI コードを書くエージェントに視覚アイデンティティを伝えるため、リポジトリルートに `DESIGN.md`（Google Labs の仕様、`version: alpha`）を置いた。この仕様は frontmatter に機械可読なデザイントークンを、本文に人間向けの意図を書く形をとる。

公式 CLI には `npx @google/design.md export --format css-tailwind` があり、`DESIGN.md` から Tailwind のテーマ CSS を生成できる。これを使えばトークンの定義が 1 箇所に収まり、二重管理を避けられる。

**しかしこのリポジトリでは成立しない。**

色・角丸・フォントの出典は `app/frontend/stylesheets/application.tailwind.css` の daisyUI テーマ `bento` であり、その語彙は daisyUI 固有である。`--color-base-100` / `--color-base-content` / `--radius-field` / `--radius-selector` / `--size-field` / `--depth` / `--noise` といった変数名は、`DESIGN.md` 仕様の `colors` / `rounded` / `spacing` / `typography` に対応物を持たない。`export` が吐くのは素の `@theme` ブロックであり、`@plugin "daisyui/theme"` に流し込めない。

## 決定

**トークンの出典は `application.tailwind.css` に残す。`DESIGN.md` の frontmatter はその写しとして扱う。**

色を変えるときは CSS を変え、`DESIGN.md` を追随させる。逆方向はしない。CLI の `export` / `diff` は使わない。

**frontmatter には選択の余地があるトークンだけを写す。**

エージェントが ERB に書くのは `btn-neutral` や `text-staff` といったクラス名であって oklch 値ではない。値の複製はそれ自体では役に立たず、乖離のリスクだけを増やす。したがって `base-100` / `base-200` / `base-300` と `*-content` 系の 11 個は写さない。これらは daisyUI の内部配線であり、エージェントが選ぶ対象ではない。退役したトークン（`accent`）も写さない。

写す価値があるのは、Chartkick のグラフ色のように**生の値が必要になる場面で選ばれうるトークン**に限る。

**`DESIGN.md` の価値は frontmatter ではなく本文に置く。**

「いつどのトークンを選ぶか」は機械可読なトークン表からは導けない。`error` が失敗ではなく「もう選べない状態」を意味することも、差額精算の 3 結果のうち返金だけが赤い理由も、散文でしか書けない。

## 検討して採らなかった案

- **変換層を自作して `DESIGN.md` から daisyUI テーマを生成する** — daisyUI の変数名と `DESIGN.md` の語彙を対応づけるスクリプトを書けば一方向の生成は組める。しかし画面数が限られ利用者が 1 人のこのアプリで、ビルドパイプラインに 1 段足して維持する価値がない。仕様が `alpha` で破壊的変更がありうることも、パイプラインに載せない理由になる。
- **daisyUI をやめて素の Tailwind テーマにする** — `export --format css-tailwind` の出力をそのまま使えるようになるが、daisyUI のコンポーネント（`btn` / `badge` / `modal` / `drawer`）を全部自前で組み直すことになる。トークンの出典を 1 箇所にするために払う代償として釣り合わない。
- **frontmatter に全トークンを写す** — 網羅すれば一貫はするが、乖離したときにどちらが正かを判断する手がかりが消える。写す範囲を「選ばれうるもの」に絞れば、乖離しても影響が限定される。
- **frontmatter を空にして本文だけにする** — 仕様が `name` と最小限のトークンを求めており、`lint` も通らなくなる。ツール中立という仕様の利点も捨てることになる。

## 結果

- **`bento` テーマの値と `DESIGN.md` の frontmatter は乖離しうる。**承知のうえで、乖離しても影響が限定される範囲だけを写している。値が必要になったら CSS を見る。
- **`DESIGN.md` に「値の出典は `application.tailwind.css` である」と明記した。**この一文が無いと、次に読む人は frontmatter を正だと解釈する。
- **CLI は `lint` だけを単発で使う。**依存には追加しない。`lint` が検証するのは構造の正しさだけで、「`btn-neutral` を主要ボタンに使う」のような実際に守りたい規約は検査できない。
- **退役したトークンは frontmatter から消す。**CSS 側には別名として残す（削ると daisyUI が独自の既定色を当てるため）が、frontmatter に残すと機械的に読むエージェントが選択可能なトークンとして扱ってしまう。
