# ADR-0003: SQLite 上での並行制御の方針

- **状態**: 承認
- **日付**: 2026-08-18
- **関連 Issue**: [#244](https://github.com/kazu-2020/bento-manager/issues/244), [#338](https://github.com/kazu-2020/bento-manager/issues/338)

## 背景

POS は複数端末から同時に打たれる。同じ販売先で会計と差額精算が重なれば、当日在庫の増減と販売の取消が並行して走る。データベースは SQLite 1 本で、Puma のスレッドと Kamal のコンテナが同じファイルを触る。

Issue #244 で、確定済みの販売を取り消す `Sale#void!` が**メモリ上の `voided?` を見てから更新していた**ため、同じ販売を読み込んだ 2 つのリクエストがどちらもガードを通過し、在庫の二重復元と `Refund` の二重作成を許すことが分かった。

修正にあたって手段が 2 つ出た。トランザクション内で reload してから判定する（`with_lock`）か、`completed` のときだけ更新する条件付き UPDATE を撃って更新件数で判定するか。前者は「SQLite では `FOR UPDATE` が無視されるので `with_lock` は行ロックにならない」という事実があるため、一見すると頼りない。後者はデータベースの挙動に依存しない。

最初の実装は後者を採ったが、その結果**同じコミットの中に 2 つの並行制御が並んだ**。在庫（`DailyInventory`）は `with_lock` に依存し、販売の取消だけが条件付き UPDATE を使う形である。しかも前者を「これで競合しない」と説明するコメントを足しながら、後者はその説明を信用しない実装になっていた。

前提そのもの（SQLite でなぜ直列化されるのか）はモデル固有ではなく、書き込みを行うすべてのモデルに効く。どこにも書かれていなかったため、この ADR で明文化する。

## 決定

### 1. 状態の判定と書き込みは、同じトランザクションの中で reload の後に行う

`with_lock` を使う。メモリ上の属性で判定して書き込む形は採らない。

```ruby
def void!(voided_by:)
  with_lock do
    raise AlreadyVoidedError, "この販売は既に取り消されています" if voided?

    update!(status: :voided, voided_at: Time.current, voided_by_employee: voided_by)
  end
end
```

**理由**: SQLite では `FOR UPDATE` が無視されるため `with_lock` は行ロックにならない。効いているのは**別の 2 つ**である。

1. `with_lock` はトランザクション内で `reload` する。判定が必ず最新の行に対して行われる。
2. sqlite3 アダプタは `BEGIN IMMEDIATE` を使い、トランザクションの最初の文で書き込みロックを取る。後続のリクエストは先行がコミットするまで `BEGIN` で待たされ、待ちが明けてから読む。

この 2 つが揃っているので、reload から `save!` までの間に他の接続が割り込む窓は無い。**行ロックが無いことは問題にならない。** 判定を「読んでから書くまでの区間」に閉じ込めることが目的であって、行ロックはその手段の 1 つにすぎない。

PostgreSQL に移せば `with_lock` は本物の `FOR UPDATE` になる。**移行で弱くなる方向の変更ではない。**

### 2. 楽観ロック（`lock_version`）は残すが、`StaleObjectError` は rescue しない

`daily_inventories` の `lock_version` は残す。`ActiveRecord::StaleObjectError` を捕まえる rescue やリトライは書かない。

**理由**: 決定 1 が守られている限り `StaleObjectError` は**到達不能**である。`daily_inventories` への書き込みは 3 経路しかない。

1. 既存行の数量更新 — `decrement_stock!` / `increment_stock!`
2. 新規作成 — `bulk_create`、`AdditionalOrder.create_with_inventory!` の `find_or_create_by!`
3. 在庫訂正による当日分の一括削除と再作成 — `bulk_recreate`（`delete_by` + `bulk_create`）

楽観ロックが問題になりうるのは 1 だけで、そこは `with_lock` の reload で `lock_version` が常に最新に揃う。到達しない例外の rescue は死んだ枝になり、読み手に「ここは競合し得る」という誤った緊張感を与える。

**3 との競合について**: `bulk_recreate` は当日分を消して作り直すので行の id が変わるが、これも `StaleObjectError` にはならない。販売と差額精算はどちらも在庫を `find_by!` でトランザクション内から引き直すため、消えた行のオブジェクトを掴んだまま更新する経路が無い。加えて `bulk_recreate` は `Sale.started?` が真なら何もせずに戻り、その判定も決定 1 と同じくトランザクション内で行われる。**仮に in-memory の `DailyInventory` をトランザクションを跨いで持ち回れば、`with_lock` の reload は `RecordNotFound` を投げる**（`StaleObjectError` ではない）。持ち回らないことが前提である。

残す理由は、**`with_lock` を外した瞬間に落ちる検知器として働く**ため。#244 の指摘（`with_lock` は SQLite では行ロックにならない）は正しく、それを理由に `with_lock` を外す変更は将来ありうる。`test/models/daily_inventory_test.rb` の「別の端末が先に当日在庫を更新していても後続の在庫増減は取りこぼされない」は、`with_lock` を外すと実際に `StaleObjectError` で落ちる。**コメントではなくテストが不変条件を支えている。**

### 3. 条件付き UPDATE（`update_all` の更新件数で判定する形）は採らない

**理由**: データベースの挙動に依存しない点は確かに強い。しかし `update_all` はバリデーションもコールバックもタイムスタンプも飛ばすため、`update!` が既にやっていることを手で書き直すことになる。#244 の最初の実装では、バリデーションを走らせるためだけに `assign_attributes` で自インスタンスを一時的に不整合な状態にし、その後始末に `reload` が要り、失敗経路では「DB と食い違ったインスタンスが呼び出し元に返る」という新しい失敗モードまで生んだ。20 行の実装が `with_lock` 版では 7 行になった。

より重いのは**機構が 2 つになること**である。次に同種のガードを書く人はどちらが正典か判断できない。SQLite の前提が変わったとき、1 箇所で済む修正が 2 箇所に散る。

### 4. `with_lock` で表現できない一度きりの制約は、データベースの制約で表現する

対象の行がまだ存在しない種類の一意性は、アプリ側のガードではなく一意インデックスで守る。既存の例は `catalog_discontinuations.catalog_id` の一意インデックス（`db/schema.rb`）で、提供終了が二重に記録されない保証はここが持っている。

**理由**: `with_lock` は既存の行を読み直す機構なので、「まだ無い行を 2 つ作る」競合には効かない。読んで無ければ作る、という形はアプリ側では必ず窓が開く。

## 前提（崩れたら見直すこと）

決定 1 は次に依存している。**Rails を上げるときはここを確認する。**

- sqlite3 アダプタが `BEGIN IMMEDIATE` を使うこと。activerecord 8.1 では `sqlite3_adapter.rb` が接続パラメータに `default_transaction_mode: :immediate` を**マージで上書きして固定**しており、`config/database.yml` からは変えられない。設定で外れる心配は無いが、アダプタ側の既定が変われば決定 1 の根拠の半分が消える
- `lock!`（`with_lock` の実体）は、未保存の変更を持つレコードに対しては例外を投げる。`with_lock` に入る前に属性を書き換えてはいけない

## 決定不要として閉じた論点

- **共有 concern への抽出**: 「一度きりの状態遷移」は `Sale#void!` にしか無い。`CatalogDiscontinuation` は決定 4 のとおり一意インデックスで守られ、`AdditionalOrder` と `Refund` は append-only で遷移が存在しない。`Employee#status` は Rodauth の管轄。**一員しかいない抽象**になるため作らない
- **`config/database.yml` への `default_transaction_mode` の明記**: 前提のとおりアダプタがマージで上書きするため、書いても効かない。効かない設定を「効いているつもりで」置くほうが有害
- **`StaleObjectError` のリトライ**: 決定 2 のとおり到達不能

## 影響

- `with_lock` の `reload` はアソシエーションキャッシュを捨てる。差額精算 1 回あたりのクエリは 14 → 17 に増える（コントローラが `preload(items: :catalog)` したものを引き直すため）。SQLite ローカルで 1ms 未満であり、機構を 1 つに保つ対価として受け入れる
- **競合した後発のリクエストは `BEGIN` で待つ。** `config/database.yml` の `timeout: 5000` を超えると `SQLite3::BusyException` が上がり、Rails はこれを `ActiveRecord::StatementTimeout` に変換する。アプリ内に rescue が無いため現状は 500 になる。**待たされた側は `AlreadyVoidedError` の親切なメッセージに到達する前に落ちる。** 差額精算は在庫復元と `Refund` 作成までトランザクションを保持するため、先行の処理が長いほどこの窓は広がる。**直列化を選んだことの裏返しであり、この方針を採る以上は待ちきれない場合の出方（再試行するのか、画面に何を出すのか、監視するのか）を決める必要がある。** [#338](https://github.com/kazu-2020/bento-manager/issues/338) で追跡する
- 決定 1 と 2 の根拠は `app/models/sale.rb` と `app/models/daily_inventory.rb` のコメントからこの ADR を参照している。前提が変わったときに直す場所は、この 3 つ

## 参照

- [Issue #244](https://github.com/kazu-2020/bento-manager/issues/244) — 二重返金の競合ガードがなく StaleObjectError も未処理
- [Issue #338](https://github.com/kazu-2020/bento-manager/issues/338) — 書き込みロック待ちのタイムアウトが 500 になる
- [SQLite: Transactions](https://www.sqlite.org/lang_transaction.html) — `DEFERRED` / `IMMEDIATE` / `EXCLUSIVE` の違い
