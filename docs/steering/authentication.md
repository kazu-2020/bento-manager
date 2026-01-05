# 認証 (Authentication) ガイドライン

rodauth-rails を使用した認証機能の実装パターン。

---

## 認証ライブラリ

- **Gem**: [rodauth-rails](https://github.com/janko/rodauth-rails)
- **選定理由**: セキュリティ重視、機能豊富、Rails 統合が良好

---

## 構成ファイル

| ファイル | 役割 |
|---------|------|
| `app/misc/rodauth_app.rb` | メインルーター（全設定の統合） |
| `app/misc/rodauth_admin.rb` | Admin 用設定 |
| `app/misc/rodauth_employee.rb` | Employee 用設定 |

---

## 新機能追加時のワークフロー

### 重要: マイグレーション生成コマンド

既存の rodauth 設定に新しい機能（OTP、パスワードリセット等）を追加する場合、**必ず** 専用ジェネレータを使用する。

```bash
# 基本形式
rails generate rodauth:migration [feature_names]

# 例: OTP と リカバリーコード を追加
rails generate rodauth:migration otp recovery_codes

# 例: メール認証機能を追加
rails generate rodauth:migration verify_account reset_password

# 例: アクティブセッション機能を追加
rails generate rodauth:migration active_sessions
```

### テーブルプレフィックス指定

デフォルト(`accounts`)以外のテーブルを使用する場合:

```bash
# Admin テーブル用
rails generate rodauth:migration [features] --prefix admin

# Employee テーブル用
rails generate rodauth:migration [features] --prefix employee
```

### 追加後の手順

1. マイグレーション実行: `rails db:migrate`
2. 対応する rodauth 設定ファイルで機能を有効化
3. ja.yml に必要な翻訳を追加

---

## 主要な Rodauth 機能一覧

| 機能名 | 用途 |
|-------|------|
| `login` | ログイン |
| `logout` | ログアウト |
| `remember` | ログイン状態の記憶 |
| `reset_password` | パスワードリセット |
| `verify_account` | アカウント確認 |
| `change_password` | パスワード変更 |
| `otp` | ワンタイムパスワード (2FA) |
| `recovery_codes` | リカバリーコード |
| `active_sessions` | アクティブセッション管理 |
| `lockout` | アカウントロック |

詳細: https://github.com/janko/rodauth-rails#features

---

## 現在の構成

- **Admin**: コンソール経由で管理、メール認証なし
- **Employee**: (実装中)

---

## 注意事項

- 手動でマイグレーションを書かず、ジェネレータを優先する
- 複数アカウントタイプがある場合はプレフィックスを忘れずに指定
- セキュリティ関連の設定変更は慎重に行う

---

_updated_at: 2026-01-05_
