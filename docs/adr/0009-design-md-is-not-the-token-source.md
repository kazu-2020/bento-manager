# DESIGN.md をデザイントークンの出典にしない

エージェントに視覚アイデンティティを伝えるためルートに `DESIGN.md`（Google Labs 仕様、alpha）を置いたが、
色・角丸・フォントの出典は従来どおり `app/frontend/stylesheets/application.tailwind.css` の daisyUI テーマ `bento` に残し、
`DESIGN.md` の frontmatter はその写しとして扱う。

## Considered Options

CLI の `npx @google/design.md export --format css-tailwind` を使えば `DESIGN.md` からテーマ CSS を生成でき、
二重管理を避けられる。しかしこのリポジトリでは成立しない。
daisyUI のテーマ契約は `--color-base-100` / `--radius-field` / `--depth` / `--noise` といった daisyUI 固有の変数名で構成されており、
DESIGN.md の仕様（`colors` / `rounded` / `spacing` / `typography`）に対応物がない。
生成される `@theme` ブロックを `@plugin "daisyui/theme"` に流し込めないため、変換層を自作しない限り一方向の生成は組めない。
画面数が限られ利用者が 1 人のこのアプリで、その変換層を持つ価値は無いと判断した。

## Consequences

`bento` テーマの値と `DESIGN.md` の frontmatter は必ず乖離する。これを承知のうえで、
frontmatter には**選択の余地があるトークンだけ**を写す（`base-*` や `*-content` のような daisyUI の内部配線は写さない）。
値が必要になったら CSS を見る。`DESIGN.md` の価値は frontmatter ではなく本文、
すなわち「いつどのトークンを選ぶか」の記述にある。
