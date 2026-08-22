# ADR-0007: 従業員のアカウント状態は「有効」と「閉鎖」の 2 つだけとする

- **状態**: 承認
- **日付**: 2026-08-22
- **関連 Issue**: [#365](https://github.com/kazu-2020/bento-manager/issues/365)
- **関連**: [ADR-0003](0003-sqlite-concurrency-control.md)

## 背景

Rodauth は `unverified` / `verified` / `closed` の 3 状態を前提に作られている。`unverified` は「登録されたメールアドレスの所有を本人が確認していない」ことを指す語彙であり、`verify_account` 機能とセットで意味を持つ。

この製品はメール機能を一切使わない。従業員は連絡先メールアドレスを持たず、`verify_account` も有効化していない。つまり `unverified` に対応する出来事が存在せず、そこから `verified` へ上げる経路も無い。

にもかかわらず `employees.status` の DB デフォルト値が `1`（unverified）だった。`status` を省いて作られたアカウントは黙って `unverified` になり、それは Rodauth のログイン経路で 403 と「verify account before logging in」を返す、**存在しない手続きを案内される使えないアカウント**である。

あわせて `ApplicationController` の `require_authentication` が `logged_in?`（実体は `session[session_key]` の有無）しか見ておらず、`current_employee` の `find_by` も状態を見ていなかった。**ログイン後に閉鎖された従業員が業務画面を使い続けられる**状態だった。

## 決定

**`unverified` を廃止し、アカウント状態を「有効」と「閉鎖」の 2 つに閉じる。**

業務画面の入口は Rodauth の `require_account` に委ねる。これが #365 の本体である。`require_account` は `require_account_session` まで面倒を見るため、閉鎖された従業員のセッションはその場で切れる。

Rodauth の `account_open_status_value` / `account_closed_status_value` は `Employee.statuses` から導出する。Rodauth の既定値 `2` / `3` と enum の値が一致しているのは偶然であり、手作業で揃えたままにすると状態を足すときに片方だけずれる。ずれても例外は出ず、`close_account` が書く値と `account_session_status_filter` が読む値が食い違うだけになる。

`account_unverified_status_value` は **enum にも DB にも存在しない `0` を番兵として置く**。`_account_from_login` の述語が `status IN (0, 2)` になり、DB に混入した `1` は候補から外れて、存在しないログイン名と同じ 401 になる。

`employees.username` の部分ユニークインデックスの述語を `status IN (1, 2)` から `status != 3` に変える。`Employee` の uniqueness バリデーションが使う `where.not(status: :closed)` と同じ式にするためである。取りうる値が 2 と 3 だけになった今は等価だが、値を列挙する形は状態が増えるたびに DB とモデルが黙ってずれる。

## 検討して採らなかった案

**`unverified` に「承認待ち」の意味を与えて残す。** 将来 LINE 認証を入れたときに「ログインしてきたが、まだ従業員として認めていない人」を表現する場所として使う案。**本人確認と就業承認は別の概念**である。LINE 認証の本質は本人確認を LINE に外注することなので、LINE 経由のアカウントは定義上「確認済み」から始まる。足りないのは店側の承認であって本人確認ではない。この 2 つを 1 つのカラムに同居させると、#365 とまったく同じ混線を自分で作り直すことになる。なお LINE 認証はアカウントを店主が先に作り、従業員が初回に LINE を紐付ける形を採るため、承認待ちの状態はそもそも生じない。

**`unverified` でも業務画面を使えるようにする。** `account_session_status_filter` を `[1, 2]` に広げる案。生む状態が無いものに合わせて入口を広げることになる。`unverified` を作る画面も、そこへ遷移させる手続きも、`verified` へ上げる経路も存在しない。

**enum には残し「今は使っていない値」として温存する。** 意味の定義されていない値が残れば、いつか誰かが使う。承認待ちが本当に必要になったときは、その時にその名前で足せばよい（`pending_approval` は `unverified` ではない）。

**`account_unverified_status_value` を有効と同じ値に倒す。** `_account_from_login` から `1` を外す効果は番兵値と同じだが、こちらは地雷になる。`verify_account` は `account_initial_status_value` をこの値へ上書きし（`verify_account.rb:202-204`）、`create_account` がそれを新規行に書く（`create_account.rb:124`）。有効と同じ値だと、**確認リンクを踏まないアカウントが最初からログインでき、業務画面まで到達する**。例外もテスト失敗も出ない。

**DB に CHECK 制約を置く。** 将来 LINE 認証の承認待ちや `verify_account` を入れるときに必ず外すことになり、SQLite ではそのたびにテーブル再作成が要る。

## 結果

ADR-0003 の「`Employee#status` は Rodauth の管轄」は、**遷移**の管轄の話として読む。取りうる値の集合はアプリが定義し、有効から閉鎖への遷移は引き続き Rodauth が行う。

CHECK 制約を置かない引き換えに、**値の集合を強制する場所は無い**。`enum` が守るのは ActiveRecord の属性代入だけで、Rodauth は Sequel で直接書き（ただし書く値は閉鎖のみ）、`update_all` と生 SQL は素通りする。集合の外の値が入りうることを承知したうえで、入っても業務画面には到達しないこと（`require_account`）で受けている。

フラッシュの二重管理が解消される。旧実装は `flash[:error]` に入れていたが、認証レイアウトが描画するのは `flash[:alert]` だけなので、案内は一度も表示されていなかった。`require_login_error_flash` に寄せたことで、設定した文言が実際に画面へ出る。

従業員アカウントを作る画面は依然として存在しない。`rails console` と `db/seeds.rb` だけである。この決定は「作られたアカウントがどの状態を取りうるか」を定めるもので、作成手段は別に扱う。
