---
paths:
  - "app/misc/rodauth_*.rb"
---

# 認証ルール（rodauth-rails）

[目的: rodauth の機能追加を手書きマイグレーションではなくジェネレータ経由で行う]

## 構成ファイル

| ファイル | 役割 |
|---------|------|
| `app/misc/rodauth_app.rb` | メインルーター（全設定の統合） |
| `app/misc/rodauth_employee.rb` | Employee 用設定 |

現在有効な構成は Employee のログインと Remember Me のみ。

## 必須ルール

### 1. マイグレーションはジェネレータで生成する

既存の rodauth 設定に機能（OTP、パスワードリセット等）を追加する場合、手動でマイグレーションを書かず専用ジェネレータを使う。

```bash
# 基本形式
bin/rails generate rodauth:migration [feature_names]

# 例: OTP とリカバリーコードを追加
bin/rails generate rodauth:migration otp recovery_codes

# 例: メール認証機能を追加
bin/rails generate rodauth:migration verify_account reset_password
```

デフォルト（`accounts`）以外のテーブルを使う場合は `--prefix` を指定する。

```bash
bin/rails generate rodauth:migration [features] --prefix employee
```

### 2. 機能追加後の手順

1. `bin/rails db:migrate` を実行
2. 対応する rodauth 設定ファイル（`rodauth_employee.rb` 等）で機能を有効化
3. `ja.yml` に必要な翻訳を追加

生成されたマイグレーションにも [migration.md](migration.md) のコメント規約を適用する。

## 主要な Rodauth 機能

| 機能名 | 用途 |
|-------|------|
| `login` / `logout` | ログイン・ログアウト |
| `remember` | ログイン状態の記憶 |
| `reset_password` | パスワードリセット |
| `verify_account` | アカウント確認 |
| `change_password` | パスワード変更 |
| `otp` / `recovery_codes` | 2FA・リカバリーコード |
| `active_sessions` | アクティブセッション管理 |
| `lockout` | アカウントロック |

詳細: https://github.com/janko/rodauth-rails#features

---
_セキュリティ関連の設定変更は、ジェネレータの生成結果を確認したうえで慎重に行うこと。_
