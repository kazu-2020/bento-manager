# ~/.config/claude → ~/.claude 移管計画

## Context

Claude Code の設定ディレクトリが `~/.config/claude`（XDG_CONFIG_HOME 由来）と `~/.claude` に分散している。
`~/.claude` に一本化し、その後 `CLAUDE_CONFIG_DIR` 環境変数の設定があれば削除する。

## 現状

| 項目 | 値 |
|------|-----|
| `~/.config/claude` | 69MB — メイン設定（settings.json, .claude.json, projects, skills, plugins 等） |
| `~/.claude` | 19MB — plugins/marketplaces のみ実質的な内容 |
| `XDG_CONFIG_HOME` | `$HOME/.config`（`~/.zshenv:2` で設定） |
| `CLAUDE_CONFIG_DIR` | 未設定（XDG_CONFIG_HOME 経由で `~/.config/claude` に解決） |

重複ディレクトリ: `cache`, `ide`, `plugins`, `skills` — `~/.config/claude` 側が正。

## 手順

### Step 1: バックアップ

```bash
cp -a ~/.config/claude ~/.config/claude.bak
```

### Step 2: ~/.config/claude の内容を ~/.claude にマージ

```bash
rsync -av ~/.config/claude/ ~/.claude/
```

### Step 3: CLAUDE_CONFIG_DIR を設定して動作確認

`~/.zshenv` に追加:
```bash
export CLAUDE_CONFIG_DIR="$HOME/.claude"
```

Claude Code を再起動し、settings.json / projects / skills / plugins が正しく読み込まれることを確認。

### Step 4: CLAUDE_CONFIG_DIR を外しても動くか確認

`~/.zshenv` から `CLAUDE_CONFIG_DIR` 行を削除し、Claude Code を再起動。
- `~/.claude` を参照すれば OK → そのまま完了
- `~/.config/claude` に戻る場合 → `CLAUDE_CONFIG_DIR="$HOME/.claude"` を残す

### Step 5: クリーンアップ

動作確認後:
```bash
rm -rf ~/.config/claude.bak
rm -rf ~/.config/claude
```

## 対象ファイル

- `~/.zshenv` — `CLAUDE_CONFIG_DIR` の追加/削除

## 検証方法

1. Claude Code を新しいターミナルで起動
2. settings.json の内容（enabledPlugins, language 等）が反映されているか確認
3. projects ディレクトリ内のメモリファイルが読み込まれるか確認
4. カスタム skills（cmux-frontend-check, start-issue 等）が利用可能か確認
