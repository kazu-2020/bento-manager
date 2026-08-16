# サーバー全損からの復旧手順

**想定する状況**: 本番の VPS が失われた。中の Docker volume も、コンテナレジストリも一緒に消えた。
S3 のバックアップと、この Git リポジトリと、1Password だけが残っている。

**目標**: 翌朝の出張販売までに、本番相当の環境を白紙の VPS 上に立て直す（ADR-0001 決定 8、RTO は一晩）。

**所要時間の目安**: 1〜2 時間。大半は VPS の払い出しと DNS の反映待ち。

> **この手順はまだ実地で検証されていない**（[#283](https://github.com/kazu-2020/bento-manager/issues/283)）。
> 詰まった箇所はその場で本ファイルを直すこと。半年後の自分が読む唯一の資料である。

## 0. 手元に揃っているか確認する

```bash
op account list                  # 1Password CLI にサインイン済みか
tailscale status                 # Tailscale に参加しているか
mise exec -- bundle exec kamal version
```

S3 にバックアップが生きていることを、サーバーを立てる前に確かめる。ここが空なら以降の手順に意味がない。

```bash
aws s3 ls s3://bento-manager-backup-394123064455/production/ --recursive | tail -5
```

## 1. 新しい VPS を用意する

Xserver VPS のコンソールから Ubuntu の VPS を 1 台作る。root の SSH 鍵は手元の公開鍵を登録する。

払い出されたら、以下の 2 つを控える。

- **グローバル IP** と、それに紐づく **ホスト名**（`x***-***-**-**.static.xvps.ne.jp`）
- root で SSH できること

```bash
ssh root@<新しいグローバル IP> 'echo OK'
```

## 2. Tailscale に参加させ、デプロイ経路を張り直す

Kamal は Tailscale 経由の `100.x.x.x` でサーバーに繋いでいる。新サーバーではこのアドレスが変わる。

```bash
ssh root@<新しいグローバル IP> 'curl -fsSL https://tailscale.com/install.sh | sh'
ssh root@<新しいグローバル IP> 'tailscale up'
```

表示された URL をブラウザで開いて承認し、割り当てられたアドレスを控える。

```bash
ssh root@<新しいグローバル IP> 'tailscale ip -4'
```

手元から Tailscale 経由で繋がることを確認する。**ここが通らないと `kamal deploy` は
「Setting up local registry port forwarding...」で無言のままハングする。**

```bash
ssh root@<新しい 100.x アドレス> 'echo OK'
```

## 3. リポジトリのホスト情報を書き換える

サーバーが変わると、Kamal の接続先（Tailscale アドレス）と公開ホスト名の両方が変わる。
書き換えるのは次の 3 箇所。**1 つでも古いままだと、証明書の取得か Host ヘッダの検証で落ちる。**

| ファイル | 項目 | 入れる値 |
|---|---|---|
| `config/deploy.yml` | `servers.web[0]` | 新しい Tailscale アドレス |
| `config/deploy.yml` | `proxy.host` | 新しい `*.static.xvps.ne.jp` |
| `config/environments/production.rb` | `config.hosts` と `action_mailer.default_url_options[:host]` | 同上 |

独自ドメインを使っている場合は、DNS の A レコードを新しいグローバル IP に向け、
反映されてから次に進む（Let's Encrypt の証明書取得が DNS を見る）。

```bash
dig +short <公開ホスト名>
```

書き換えたらコミットしておく。以降の `kamal deploy` は作業ツリーの内容をビルドする。

## 4. サーバーに Docker を入れる

```bash
mise exec -- bundle exec kamal server bootstrap
```

## 5. コンテナレジストリを建て直す

レジストリは `localhost:5550` としてサーバー側に同居しているため、全損時に一緒に消えている
（ADR-0001 決定 8）。イメージはソースから再ビルドできるのでデータ損失ではないが、
**これが無いと `kamal deploy` の push が失敗する。**

```bash
ssh root@<新しい 100.x アドレス> \
  'docker run -d --restart always --name registry -p 127.0.0.1:5550:5000 registry:2'
```

## 6. 1Password からシークレットを取得できることを確かめる

`kamal deploy` は `.kamal/secrets` を毎回評価し、1Password から値を引く。**ここが失敗すると
デプロイは途中で止まる**ので、ビルドを待つ前に確かめる。

```bash
op signin
mise exec -- bundle exec kamal secrets print
```

`SECRET_KEY_BASE` / `SENTRY_DSN` / `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` の 4 つが
値付きで出れば通っている（値は端末に出るので、共有画面では叩かないこと）。

`item not found` で落ちる場合は、`.kamal/secrets` の `--account` と `--from` が指す
1Password のアカウント・vault item が生きているかを確認する。**AWS の 2 つが欠けていると、
手順 8 のレプリケーション再開だけが後から静かに失敗する**ので、ここで揃っていることを見る。

## 7. アプリをデプロイする（この時点ではまだ空の DB）

```bash
mise exec -- bundle exec kamal deploy
```

`bin/docker-entrypoint` の `db:prepare` が空の `production.sqlite3` を作る。これは想定どおりで、
次の手順で本物に置き換える。

> **`kamal setup` を使ってはならない。** setup は accessory も一緒に起動する。
> Litestream が空の DB を掴むと、その空の状態が S3 に複製され、**復旧しようとしていた
> バックアップを自分で壊す。** `kamal deploy` は accessory を起動しないので安全である
> （ADR-0001 決定 3 で「負債」として引き受けた性質が、ここでは安全装置として働く）。

## 8. データベースを復元する

アプリを止めてから、volume 上の DB ファイルを S3 の中身で上書きする。
止めずに上書きすると、Rails が開いたままのファイルを差し替えることになる。

```bash
mise exec -- bundle exec kamal app stop

mise exec -- bundle exec kamal app exec \
  "litestream restore -config /rails/config/litestream.yml -force -o /rails/storage/production.sqlite3 /rails/storage/production.sqlite3"
```

`--reuse` を付けないこと。付けると停止中のコンテナを掴もうとして失敗する。
`--reuse` なしの `app exec` は同じ volume をマウントした一時コンテナを新しく立てるので、
アプリが止まっていても volume 上のファイルに手を入れられる。

復元されたか、件数で確かめる。

```bash
mise exec -- bundle exec kamal app exec \
  "sqlite3 /rails/storage/production.sqlite3 'SELECT COUNT(*), MAX(id) FROM sales'"
```

アプリを起動し直す。entrypoint の `db:prepare` は、復元済みの DB に対して
未適用のマイグレーションだけを流す。

```bash
mise exec -- bundle exec kamal app boot
```

## 9. レプリケーションを再開する

**必ず復元の後で起動する。** 順序を逆にすると手順 7 の空 DB が S3 に複製される。

```bash
mise exec -- bundle exec kamal accessory boot litestream
mise exec -- bundle exec kamal accessory logs litestream
```

ログに `AccessDenied` が出る場合は IAM 側の問題。`s3:GetBucketLocation` を含む
専用ユーザーのポリシーは `infra/terraform/backup.tf` にある（ADR-0002）。

## 10. 復旧を確認する

```bash
# 1. ヘルスチェック
curl -sSf https://<公開ホスト名>/up

# 2. 売上データが戻っていること（全損直前の件数と突き合わせる）
mise exec -- bundle exec kamal app exec --reuse "bin/rails runner 'puts Sale.count'"

# 3. S3 に新しいオブジェクトが増えていること（数分待ってから）
aws s3 ls s3://bento-manager-backup-394123064455/production/ --recursive | tail -3

# 4. リストア訓練を手で 1 回回し、緑になること
mise exec -- bundle exec kamal app exec --reuse \
  "bin/rails runner 'pp Backups::RestoreDrill.new.run'"
```

4 が `passed=true` を返せば、バックアップと監視の両方が復旧している。
Sentry の [monitor ページ](https://matazou.sentry.io/crons/bento-manager/litestream-restore-drill/)
にチェックインが 1 件増えていることも確認する。

最後に、ブラウザから実際にログインして 1 件販売を記録し、POS が使える状態であることを確かめる。

## 参照

- [ADR-0001: SQLite のオフサーバーバックアップ戦略](../adr/0001-sqlite-offsite-backup.md)
- [ADR-0002: バックアップ基盤の構成](../adr/0002-backup-infrastructure.md)
