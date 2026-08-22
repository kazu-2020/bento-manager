# 従業員のアカウント状態は「有効」と「閉鎖」の 2 つだけとする

Rodauth は `unverified` / `verified` / `closed` の 3 状態を前提に作られているが、`unverified` は「登録されたメールアドレスの所有を本人が確認していない」ことを指す語彙であり、メール機能を一切使わないこの製品には対応する出来事が無い。にもかかわらず DB のデフォルト値が `unverified` だったため、`status` を省いて作られたアカウントは黙って `unverified` になっていた。それは Rodauth のログイン経路で 403 と「verify account before logging in」を返す、**存在しない手続きを案内される使えないアカウント**である（#365）。`unverified` を廃止し、アカウント状態を「有効」と「閉鎖」の 2 つに閉じる。

## 選択肢

**`unverified` に「承認待ち」の意味を与えて残す。** 将来 LINE 認証を入れたときに「ログインしてきたが、まだ従業員として認めていない人」を表現する場所として使う案。採らなかった。**本人確認と就業承認は別の概念**だからである。LINE 認証の本質は本人確認を LINE に外注することなので、LINE 経由のアカウントは定義上「確認済み」から始まる。足りないのは店側の承認であって本人確認ではない。この 2 つを 1 つのカラムに同居させると、#365 とまったく同じ混線を自分で作り直すことになる。なお LINE 認証はアカウントを店主が先に作り、従業員が初回に LINE を紐付ける形を採るため、承認待ちの状態はそもそも生じない。

**`unverified` でも業務画面を使えるようにする。** `account_session_status_filter` を `[1, 2]` に広げる案。採らなかった。生む状態が無いものに合わせて入口を広げることになる。`unverified` を作る画面も、そこへ遷移させる手続きも、`verified` へ上げる経路（`verify_account`）も存在しない。

**enum には残し「今は使っていない値」として温存する。** 採らなかった。意味の定義されていない値が残れば、いつか誰かが使う。承認待ちが本当に必要になったときは、その時にその名前で足せばよい（`pending_approval` は `unverified` ではない）。

## 帰結

業務画面の入口は Rodauth の `require_account` に委ねる。**これが #365 の本体である。** 従来の `require_authentication` は `logged_in?`（実体は `session[session_key]` の有無）しか見ておらず、`current_employee` の `find_by` も状態を見ていなかったため、**ログイン後に閉鎖された従業員が業務画面を使い続けられていた**。`require_account` は `require_account_session` まで面倒を見るので、この穴が塞がる。

`account_unverified_status_value` を `account_open_status_value` に倒す。Rodauth のログイン経路は `_account_from_login` が `[unverified, verified]` を引いたうえで `open_account?` で `verified` 以外を弾くため、DB に `1` が混入すると 403 と「verify account before logging in」を返す。この製品に確認手続きは無く、案内できる次の一手が存在しない。有効と同じ値に倒せば候補から外れ、存在しないログイン名と同じ 401 になる。

`employees.username` の部分ユニークインデックスの述語を `status IN (1, 2)` から `status != 3` に変える。`Employee` の uniqueness バリデーションが使う `where.not(status: :closed)` と同じ式にするためである。取りうる値が 2 と 3 だけになった今は等価だが、値を列挙する形は状態が増えるたびに DB とモデルが黙ってずれる。

ADR 0003 の「`Employee#status` は Rodauth の管轄」は、**遷移**の管轄の話として読む。取りうる値の集合はアプリが定義し、有効から閉鎖への遷移は引き続き Rodauth が行う。

Rodauth の `account_open_status_value` / `account_closed_status_value` は `Employee.statuses` から導出する。Rodauth の既定値 2 / 3 と enum の値が一致しているのは偶然であり、手作業で揃えたままにすると状態を足すときに片方だけずれる。ずれても例外は出ず、`close_account` が書く値と `account_session_status_filter` が読む値が食い違うだけになる。

`account_unverified_status_value` は有効と同じ値に倒す。**`verify_account` を入れるときはこの上書きを先に外すこと。** 未確認と有効が同じ値のままだと、確認手続きが作成直後に通ってしまう。

DB には CHECK 制約を置かない。将来 LINE 認証の承認待ちや `verify_account` を入れるときに必ず外すことになり、SQLite ではそのたびにテーブル再作成が要るためである。引き換えに、**値の集合を強制する場所は無い**。`enum` が守るのは ActiveRecord の属性代入だけで、Rodauth は Sequel で直接書き（ただし書く値は閉鎖のみ）、`update_all` と生 SQL は素通りする。集合の外の値が入りうることを承知したうえで、入っても業務画面には到達しないこと（`require_account`）で受けている。
