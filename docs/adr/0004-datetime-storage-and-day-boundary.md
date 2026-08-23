# ADR-0004: 日時の保存と「日」の境界

- **状態**: 承認
- **日付**: 2026-08-19
- **関連 Issue**: [#352](https://github.com/kazu-2020/bento-manager/issues/352), [#354](https://github.com/kazu-2020/bento-manager/issues/354), [#358](https://github.com/kazu-2020/bento-manager/issues/358), [#424](https://github.com/kazu-2020/bento-manager/issues/424)

## 背景

Rails の既定に従い、datetime は UTC で保存し、`config.time_zone = "Tokyo"` で入出力を JST に変換している。この変換は **Ruby と DB の境界を跨ぐ値**にだけ効く。書き込む値、読み出した値、`where` に渡すバインド値はすべて自動で変換される。

**届かないのは、DB エンジンの内部で行われる計算である。** `DATE(sale_datetime)` を実行するのは SQLite であり、保存されている生の UTC 文字列を、ActiveRecord が一切関与しないまま切る。結果の `"2026-08-09"` は導出値でカラム型を持たないため、読み出し時の型キャストも適用されない。設定が足りないのではなく、`default_timezone` をどう設定しても届かない領域である。

この事実がどこにも書かれていなかったため、同じ根を持つ不具合が独立に 2 件出た。

- [#352](https://github.com/kazu-2020/bento-manager/issues/352) — `DATE(sale_datetime)` が UTC 基準で日を切り、JST 0:00〜9:00 の販売が前日に寄っていた。同じ回避策が `Location` と `Sales::HistoryCalendar` にコピーされ、さらに 3 つ目の複製が `lib/tasks/sample_data.rake` にオフセット無しのまま残っていた
- [#358](https://github.com/kazu-2020/bento-manager/issues/358) — `CatalogPrice` が `Date` を UTC 0 時（JST の 9 時）に寄せていた。設計判断ではなく、SQLite の文字列比較の副作用がそのまま境界の仕様になったもの。決定 3 と決定 5 で決着させた

どちらも「瞬間から暦日を導出するとき、どのタイムゾーンで切るか」を誰も決めていなかったことに由来する。

前提となる制約が 1 つある。**SQLite はタイムゾーンデータベースを持たない。** PostgreSQL の `AT TIME ZONE 'Asia/Tokyo'` や MySQL の `CONVERT_TZ()` に相当する機能が無く、`DATE(col, '+09:00')` のように**固定オフセットを加算することしかできない**。

## 決定

### 1. datetime は UTC で保存する（`default_timezone` は既定のまま触らない）

`config.active_record.default_timezone = :local` には切り替えない。

**理由**: `:local` にすれば `DATE(sale_datetime)` はそのまま動くようになり、決定 4 が丸ごと不要になる。それでも採らない理由は 3 つある。

1. **DB の外との突き合わせが恒久的に崩れる**。Sentry のイベント時刻は UTC で、現状は DB の値とそのまま照合できる。JST 保存にすると、エラーの起きた瞬間の販売レコードを探すたびに ±9 時間の暗算が要る。一度きりではなく永久に払うコストである。AWS 側のバックアップ運用（[ADR-0001](0001-sqlite-offsite-backup.md) / [ADR-0002](0002-backup-infrastructure.md)）も同じ
2. **Solid 系 3 つが巻き添えになる**。`ActiveRecord.default_timezone` はグローバルで、Queue / Cache / Cable も同じ設定を共有する。触るつもりのないインフラの時刻の意味が変わる
3. 本番稼働後は、全 datetime カラムを +9 時間ずらす移行が必要になる。**1 テーブルでも漏らすと、その行が旧 era なのか新 era なのか値からは永遠に判別できない**。売上台帳で負うリスクではない

得られるものは SQL 式から `'+09:00'` が消えることだけで、対価に見合わない。

### 2. 「日」は JST の暦日とする。業務日の独自定義は持たない

`CONTEXT.md` の「当日」と同義。

**理由**: 役場への出張訪問販売は昼前後に完結し、日付をまたがない。深夜営業の飲食店が持つ「業務日は朝 5 時始まり」のような定義は、暦日と一致するため不要である。将来カバーする話でもない。

### 3. ドメイン概念が「日」であるものは `date` カラムで持ち、timestamp から導出しない

`date` にはタイムゾーンの概念が無く、この決定に従う限り境界の問題がそもそも発生しない。既にそうなっているもの:

| テーブル | カラム |
|---|---|
| `daily_inventories` | `inventory_date` |
| `catalog_pricing_rules` | `valid_from` / `valid_until` |
| `discounts` | `valid_from` / `valid_until` |

**例外は `catalog_prices.effective_from` / `effective_until` で、姉妹概念が `date` である中でここだけ `datetime` になっている。これは [#358](https://github.com/kazu-2020/bento-manager/issues/358) で承認済みの例外である。**

`date` に寄せると、**同じ日に 2 回価格を変えたときに履歴が表現できなくなる**。`CatalogPrice.create_with_history!` は旧行を「今」で閉じて新行を「今」から開くので、`date` では旧行が `valid_until: 今日`、新行が `valid_from: 今日` となり、両方がその日有効になる。どちらが勝つかは `id` の順という実装都合でしか決まらず、「今日この商品はいくらか」に構造として一意に答えられない。値段の打ち間違いをその場で訂正するだけでもこの状態に入るため、「日の途中で値段を変えない」運用でも踏む。

寄せて得られるのは姉妹概念との型の一貫性だけで、境界の問題そのものは決定 5 のガードで閉じる。`sale_items` が `unit_price` と `catalog_price_id` の両方を保存しているため、過去の販売金額はこの型の選択に影響されない。

有効期間は**両端 inclusive** とする。`create_with_history!` が旧行の `effective_until` と新行の `effective_from` に同じ時刻を入れるため、切り替えのその一点だけは 2 件とも有効になる。半開区間 `[from, until)` にすればこの重なりは消えるが、Ruby に「開始端 exclusive」の Range リテラルが無いため `effective_at` スコープが生の SQL 断片に落ちる。重なりは 1 マイクロ秒幅で、SQL 版（`price_by_kind`）と Ruby 版（`pick_by_kind`）が同じ勝者を返すことは `test/models/catalog_test.rb` の「価格の読み込み済みかどうかで、取得できる価格は変わらない」が担保している。

**この規約を変えるなら、先に読む場所が 3 つある。** `CatalogPriceTest` の「新しい価格を設定すると既存の価格が終了する」（切り替えの一点で 2 件が有効になることを `assert_equal 2` で固定している）、同じく「有効期間は開始と終了のちょうどその時刻も含む」（両端そのものが含まれることを Ruby 版・SQL 版の両方で見ている）、そして上記の同値性テストである。

`sales.sale_datetime` は瞬間そのものが要る（販売開始の判定、差額精算の当日判定、履歴の時刻表示）ため、この決定の対象ではない。

### 4. SQL で timestamp から日を切り出すときは `Sale.jst_date_expression` を通す

生の `DATE(col)` をアプリケーションコードに書かない。rake タスクも含む。

```ruby
def self.jst_date_expression
  Arel.sql(sanitize_sql_array([ "DATE(sale_datetime, ?)", Time.zone.now.formatted_offset ]))
end
```

**理由**: これは環境の落とし穴に対する防御であり、コピーが増えるほど片方だけ直され忘れる事故に近づく。#352 で実際にそうなった（2 箇所の重複に加えて、オフセット無しの 3 つ目が rake タスクに残っていた）。

オフセットを `'+09:00'` と直書きせず `Time.zone.now.formatted_offset` から引くのは、`config.time_zone` を変えたときに SQL 側だけ取り残されないため。`Time.zone.formatted_offset`（`.now` 無し）ではないのは、前者がゾーンの**標準時**オフセットを返すのに対し、求めているのが**その瞬間の実効**オフセットだからである。日本には夏時間が無いため両者に差は出ないが、意味として後者が正しい。

### 5. `Date` を SQL の datetime カラムと直接突き合わせない

**理由**: `Date` を `where` にそのまま渡すと `'YYYY-MM-DD'` として引用され、UTC 保存の datetime 文字列との**文字列比較**になる。この比較は開始端だけが exclusive という非対称を持ち（`'2026-08-18 00:00:00.000000'` は前方一致で長い分だけ大きく、`'2026-08-18'` 以下にならない）、Ruby 側の日時比較では書き起こせない。#354 で、preload の有無によって同じ問い合わせの答えが割れる形で表面化した。

突き合わせるなら Ruby 側で `Time` に変換してから渡す。**そのとき「その日のどの瞬間か」を決めるのは呼び出し側の責任**であり、暗黙に決めてはならない。決定 3 に従っていれば、そもそもこの状況に至らない。

決定 3 の例外である `CatalogPrice` では、この決定を `CatalogPrice.assert_instant!` が実行時に検査する。基準日時を受け取る公開の入口すべて（SQL 版のスコープ、Ruby 版の述語、読み込み済みからの選択）がこれを通る。**暗黙に瞬間へ寄せない**のがこのガードの要点である。#358 で問題になっていた「UTC 0 時＝JST 9 時」という境界は、まさに寄せ方を誰も決めないまま文字列比較の副作用として残ったものだった。行数に関わらず落ちる SQL 版と揃えるため、読み込み済みの価格が空でも落ちる位置に置いてある。

判定は `acts_like?(:time)` で**受理する側**を見る。`Time` / `DateTime` / `ActiveSupport::TimeWithZone` が通り、それ以外は落ちる。拒否する型を数える形（`instance_of?(Date)`）にしないのは、`nil` や文字列が素通りして `where(effective_from: ..nil)` が全件一致するような壊れ方をするためである。静的な型検査ではなく、実行時の検査である。

**このガードを入れても保存済みの価格の有効性は 1 件も動かない。** 置き換える前の `boundary_time` は `Date` を UTC 0 時へ寄せていたが、その分岐に入る本番の呼び出しは 1 つも無かった（唯一 `Date` を渡していた `Catalogs::PricingRuleCreator` は本番から一度も参照されないまま #358 で削除した）。`Time` は以前から素通しで、境界の位置も比較の向きも変わっていない。したがって **JST 0 時〜9 時に作成された価格の扱いも変わらず、データ移行は不要である。**

## 前提（崩れたら見直すこと）

- **日本国内のみで運用すること。** 決定 4 の実装は、全行に単一の固定オフセットを適用する。夏時間のある地域では、移行日をまたぐ集計が必ず一部ずれる。`Time.zone.now.formatted_offset` が見ているのは「クエリを投げた瞬間」の実効オフセットであって「各行の販売時刻」のものではないためである。行ごとに正しいオフセットを引くにはタイムゾーンデータベースが要り、**SQLite では構造的に不可能**。この実装が成立しているのは日本に夏時間が無いことに依存している
- **SQLite を使い続けること。** PostgreSQL に移せば `AT TIME ZONE 'Asia/Tokyo'` が行ごとに正しく処理するため、決定 4 は不要になり決定 5 の非対称も消える。移行で弱くなる方向の決定ではない
- **`config.time_zone` が単一であること。** 販売先ごとにタイムゾーンが異なる運用は想定していない

## 決定不要として閉じた論点

- **`sales.sale_date`（`date` カラム）の追加**: 日次集計がこのアプリの主機能である以上、日を導出ではなく記録として持つ設計は筋が通る。採らない理由は規模で、日 50 件程度ではインデックスの差が測定できず、`sale_datetime` と同期を保つ不変条件が 1 つ増える対価に見合わない。**集計が重くなったら再検討する**。決定 3 との違いは、`sale_datetime` が瞬間として必要であり、日付カラムは導出結果の非正規化になる点にある
- **Ruby 側での `group_by`**: `sales.group_by { |s| s.sale_datetime.to_date }` は正しく動く（各値が JST に復元されるため）。採らないのは、集計対象の全行をメモリに載せて SQL 集計の利点を捨てるため
- **`DATE(col, 'localtime')`**: SQLite プロセスの OS のタイムゾーンを参照する。開発機（JST）では通り、CI と本番（UTC）で壊れる。アプリのタイムゾーンを明示的に渡さなければならない
- **`substr(sale_datetime, 1, 10)`**: 日は切れるがオフセットを渡せず、UTC のまま直しようがない

## 影響

- **日次集計は式でグルーピングするためインデックスが効かない。** SQLite は temp B-tree でソートする。ただし `WHERE` 側（`in_period` / `at_location`）は素の `sale_datetime` カラムなので絞り込みのインデックスは効いたままで、対象は 1 販売先 1 ヶ月ぶん。この規模では測定できない差である
- **決定 4 に反する記述は静かに壊れる。** 件数も合計金額も正しく、日付の振り分けだけがずれるため、合計を見ても気づけない。**日付の境界を扱うテストは JST 0:00 前後をまたぐデータを含めること。** `test/models/sale_test.rb` の「日付をまたぐ深夜帯の販売も、その日の売上としてまとめて集計される」がその役割を持つ
- **フィクスチャの相対時刻は 0 時台に落ちる。** `1.hour.ago` は JST 0 時台に走ると前日になる。当日であることが前提のフィクスチャは `[ 1.hour.ago, Time.current.beginning_of_day ].max` のように下限を切る（`test/fixtures/sales.yml` の `voided_sale`）。CI の実行時刻は選べないため、これはフレークではなく仕様として扱う
- **サンプルデータが営業時間帯しか生成しないと、この種の破れは開発中に一度も表に出ない。** `lib/tasks/sample_data.rake` に深夜帯の販売を混ぜておくと、壊れた瞬間に画面で気づける
- 決定 4 の根拠は `app/models/sale.rb` のコメントからこの ADR を参照している。前提が変わったときに直す場所は、この ADR と `Sale.jst_date_expression`、そして上記のテストの 3 つ

## 参照

- [Issue #352](https://github.com/kazu-2020/bento-manager/issues/352) — JST 日付式が 2 箇所に重複していた
- [Issue #354](https://github.com/kazu-2020/bento-manager/issues/354) — `Date` を `where` に渡したときの文字列比較の非対称
- [Issue #358](https://github.com/kazu-2020/bento-manager/issues/358) — 価格の有効期間の境界が UTC 0 時になっていた。決定 3 の例外を承認し、決定 5 のガードを入れた
- [Issue #424](https://github.com/kazu-2020/bento-manager/issues/424) — #358 で削除した価格存在検証の退避先。価格ルールの書き込み経路を増やすときに入れる
- [SQLite: Date And Time Functions](https://www.sqlite.org/lang_datefunc.html) — 修飾子と `localtime` の挙動
