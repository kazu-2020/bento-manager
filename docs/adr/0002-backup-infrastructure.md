# ADR-0002: バックアップ基盤の配置と構築手段

- **状態**: 承認
- **日付**: 2026-08-16
- **関連**: [ADR-0001](0001-sqlite-offsite-backup.md)

## 背景

ADR-0001 は保存先を AWS S3 (`ap-northeast-1`) と決めたが、**どのアカウントに置くか**と**何で構築するか**を決めていなかった。バケットは未作成のまま残っていた。

前提として、AWS Organizations は Control Tower 4.0 の管理下にある。統治リージョンは `ap-northeast-1` のみで、`AWS-GR_REGION_DENY` により他リージョンは拒否される。

## 決定

### 1. 専用 AWS アカウントを新設し、そこに置く

`bento-manager` (394123064455) を作成する。S3 バケットと Litestream 用 IAM ユーザーはこのアカウントに置く。**新しい AWS Organizations は作らない。**

**理由**: AWS アカウントは 1 つの組織にしか所属できないため、「専用の組織」を作ると請求・Control Tower・Identity Center・組織 CloudTrail のすべてが二重になる。これは ADR-0001 決定 2 が Cloudflare R2 を却下した理由と正面から矛盾する。

> 既にアカウントを保有しており、請求先と管理画面を増やさないことの価値が月数十円の差を上回る

管理画面を増やさないために R2 を捨てておきながら、そのために組織を増やすのでは本末転倒である。分離が必要なのは組織ではなくアカウントであり、AWS で最も強い分離境界はアカウントである。

**なぜ既存のアカウントを流用しないか**: 用途の違うアカウントに相乗りさせると、そのアカウントを整理したくなったときに「消したいが中にバックアップがある」という状態になる。バックアップは他の都合に引きずられてはならない。

**なぜ管理アカウントに置かないか**: 管理アカウントは SCP が効かない特別なアカウントであり、Organizations と Control Tower の制御に専念させる。加えて日常的に誰も見に行かない場所であるため、置いたものは放置されやすい。

### 2. Workloads OU を新設して配置する

Sandbox OU には入れない。OU は Control Tower のベースライン（`AWSControlTowerBaseline` v5.0）を適用して登録する。

**理由**: Sandbox OU は「壊してよい場所」という意味を持つ区画である。本番データのバックアップ先をそこに置くと OU 名が嘘になる。OU は SCP の適用単位でもあるため、将来「本番ワークロードにはこれを禁止する」というガードレールを足すときの受け皿にもなる。

Organizations API で OU を作っただけでは Control Tower の管理外になり、ガードレールが適用されない。ベースラインの適用まで行って初めて登録が完了する。

### 3. 構築は HCP Terraform の VCS ワークフローで行い、Auto-apply は無効にする

`infra/` 配下の変更だけをトリガーとし、apply は手動承認とする。

**理由**: CLI 駆動だと手元から `terraform apply` できてしまい、**適用された状態と git に入っているコードがずれても誰も気づかない**。1 人運用でレビューする他人がいない以上、git を通す経路を強制する仕組みそのものが唯一のチェックになる。

Auto-apply を無効にするのは、このワークスペースが売上台帳の**唯一のバックアップ先**を管理するため。バケットポリシーやライフサイクルの書き間違いが、plan を誰も見ないまま反映される経路を作らない。plan を確認してから承認する一拍が、事実上唯一の防波堤である。

パスフィルタを設定しないと Rails 側のコミット全部で plan が走り、通知が無意味になって本当に見るべき run を見落とす。

### 4. AWS への認証は OIDC による動的認証情報とする

静的なアクセスキーを HCP Terraform に保存しない。信頼ポリシーの `sub` はワークスペースを名指しで固定する。

**理由**: 静的なアクセスキーは、保存された時点から棚卸しの対象外になりやすく、使われなくなっても有効なまま残る。OIDC なら run のたびに短命のクレデンシャルが発行され、**保存されるものが存在しない**ため、この失敗モード自体が消える。

`sub` にワイルドカードを使うと、**組織内の任意のワークスペースがこのロールを引ける**。バックアップを消せる権限を、無関係なワークスペースに配ることになる。

```
organization:matazou_organization:project:workload:workspace:bento-manager:run_phase:*
```

### 5. ロールの信頼関係は HCP Terraform、権限は CloudFormation が持つ

HCP Terraform の Dynamic provider credentials 機能がロールと OIDC プロバイダー（信頼関係のみ）を作り、権限ポリシーは `infra/bootstrap/tfc-run-role-policy.yaml` が定義してアタッチする。

**理由**: ブートストラップ問題がある。HCP Terraform が AWS を操作するための IAM ロールを、まだ認証できない HCP Terraform 自身では作れない。この 1 段だけは外から与える必要がある。

権限を HCP Terraform 任せにしない理由は ADR-0001 決定 2 と同じ原則である。

> 1 人運用で事故は忘れた頃に起きる以上、コードに残らない設定は負債である

画面から手でアタッチしたポリシーは、1 年後に「これは何のための権限か」を辿る手段がない。権限は S3 をバケット名プレフィックスで、IAM ユーザーをパスで限定し、`iam:AttachUserPolicy` を意図的に除外して `AdministratorAccess` をアタッチする経路を塞いでいる。

### 6. Litestream のアクセスキーは Terraform で作らない

Terraform は IAM ユーザーとインラインポリシーまでを管理する。アクセスキーは手動で発行し、1Password に保存して kamal secrets 経由で本番に渡す。

**理由**: `aws_iam_access_key` を使うと、**シークレットが state に平文で載る**。HCP Terraform の state は暗号化保存されるが、state を閲覧できる者は秘密を読める。ADR-0001 の前提どおり 1Password は既に本番運用に組み込まれており、秘密の置き場所としてはそちらが正しい。

副次的な利点として、キーのローテーションに `terraform apply` が不要になる。ローテーションを重い操作にしないこと自体が、ローテーションを実際に行う確率を上げる。

## 決定不要として閉じた論点

- **plan / apply でロールを分ける**: `run_phase` を `plan` / `apply` に固定した 2 つのロールを作れば、plan フェーズから書き込み権限を外せる。ただし Terraform の plan は本来読み取りのみであり、この規模では管理対象を倍にするだけの実益がない。
- **run ロールの Resource 限定**: バケット名のプレフィックスや IAM ユーザーのパスで Resource を絞ることも検討したが採らない。**このアカウントは bento-manager 専用であり、保護すべき「他のリソース」が存在しない。** 守りたい当のバケットが限定範囲の中にいる以上、限定に防御としての実体はなく、Terraform 側の命名と CloudFormation 側のパラメータという暗黙の結合だけが残る。片方を変えただけでは検知されず `AccessDenied` になる類の負債である。代わりにアクションを絞り、EC2 等の起動（コスト）と `iam:CreateRole`（他アカウントから引けるロールの作成）を塞いでいる。
- **Permissions Boundary の強制**: run ロールは `iam:PutUserPolicy` を持つため、理屈の上では強い権限を持つ IAM ユーザーを作れる。ただし影響は bento-manager アカウント内に閉じており、決定 1 のアカウント分離が主たる防御線として機能している。Boundary を足すのはこのアカウントに他のワークロードが同居し始めてからでよい。
- **保管時の暗号化**: ADR-0001 で決定不要として閉じたとおり SSE-S3 で充足する。ただし既定に依存せず `aws_s3_bucket_server_side_encryption_configuration` で明示する。

## 影響

- 管理対象が増える: AWS アカウント 1 つ、HCP Terraform ワークスペース 1 つ、CloudFormation スタック 1 つ
- Control Tower のベースラインにより新アカウントでも AWS Config が有効になり、月 $0.05 程度の増加
- ワークスペースの環境変数 `TFC_AWS_RUN_ROLE_ARN` は HCP Terraform の画面にしか存在しない。ロール名を変える場合は AWS 側と両方を直す必要がある
- `s3:ListBucket` に `s3:prefix` の Condition を付けているため、Litestream がプレフィックスなしで列挙する挙動を示した場合は `AccessDenied` になる。その際は Condition を外し、Resource 側のプレフィックス限定だけを残す

## 参照

- [HCP Terraform Dynamic Provider Credentials (AWS)](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)
- [AWS::IAM::OIDCProvider](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-iam-oidcprovider.html)
- [Control Tower のベースラインと OU 登録](https://docs.aws.amazon.com/controltower/latest/userguide/types-of-baselines.html)
