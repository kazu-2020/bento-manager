# プロジェクトの目的

小さなお弁当屋さんで働く母が、役場等への出張訪問販売を手助けするためのアプリケーション

## コア原則

- **シンプル第一**: 変更は可能な限り単純に。影響範囲は最小限に。
- **怠らない**: 根本原因を解決する。応急処置は禁止。シニア水準。
- **最小影響**: 必要な箇所だけ変更し、新たなバグを生まない。
- **対等な関係**: ユーザーからの提案にただ Yes で答えるのは悪いこと。客観的な事実から否定的な案を出すことを仕事を行う上で建設的なこと

## アーキテクチャ方針

- **Fat Models, Skinny Controllers**: ビジネスロジックはモデルに置き、コントローラは HTTP の処理だけを担う
- **Service オブジェクトは絶対作成しない**: モデルを跨ぐ複雑な処理は `app/models` 配下に適切なディレクトリ階層を作り、PORO なクラスで対応する（例: `app/models/sales/recorder.rb`）
- **サーバー駆動の UI**: クライアントサイドのテンプレートではなく Turbo Frames / Streams で更新する。Stimulus は補助に留める

## 技術選定の理由

- **Hotwire（Turbo + Stimulus）**: React/Vue を使わず、開発速度と複雑さの低減を優先
- **Solid Cache / Queue / Cable**: Redis や Sidekiq を持たず、DB のみでインフラを完結させる
- **SQLite のマルチDB構成**: primary / cache / queue / cable を分離して相互影響を避ける
- **Vite**: Sprockets / Webpacker ではなく、HMR と高速ビルドを得るため
- **ViewComponent**: ERB パーシャルよりテストしやすく、テンプレート・ロジック・Stimulus コントローラーを同居させられるため

各ファイル種別の詳細なルールは `.claude/rules/` を参照（編集対象のパスに応じて自動で読み込まれる）。

## 開発コマンドの実行

`bin/rails` `bin/dev` などの shebang は `#!/usr/bin/env ruby` で、この環境では **macOS のシステム Ruby 2.6 を掴んで `Gemfile.lock` の bundler が見つからず落ちる**。`mise exec -- bin/rails` でも回避できない（`mise exec -- ruby -v` は 4.x を返すのに、shebang 経由では 2.6 になる）。mise の Ruby を PATH の先頭に置くこと。

```bash
export PATH="$(mise which ruby | xargs dirname):$PATH"
```

あわせて `LANG` が未設定だと Ruby のロケールが US-ASCII になり、日本語を含むファイルの読み込みで失敗する。`LANG=ja_JP.UTF-8` を設定する。

`.claude/launch.json`（プレビュー用の dev サーバー設定）は、この 2 つを起動コマンドに含めてある。

## Agent skills

### Issue tracker

イシューは GitHub Issues（`kazu-2020/bento-manager`）で管理し、`gh` CLI で操作する。詳細は `docs/agents/issue-tracker.md` を参照。

### Triage labels

triage の 5 つのラベルはデフォルト名をそのまま使用する。詳細は `docs/agents/triage-labels.md` を参照。

### Domain docs

single-context 構成（ルートの `CONTEXT.md` + `docs/adr/`）。詳細は `docs/agents/domain.md` を参照。
