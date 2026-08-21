# ADR-0005: 弁当とサラダを 1 つのテーブルと enum で表す

- **状態**: 承認
- **日付**: 2026-08-22
- **関連 Issue**: [#320](https://github.com/kazu-2020/bento-manager/issues/320)

## 背景

母の語彙には「弁当」と「サラダ」しかなく、この 2 つをまとめて呼ぶ言葉が無い。我々はそこに `Catalog` という箱を作り、`enum :category, { bento: 0, side_menu: 1 }` で区別することにした。「サイドメニュー」も母の言葉ではなく、サラダを入れるために作った造語である。

**この抽象は片側でしか効いていない。**

在庫と販売では本物の抽象である。弁当もサラダも同じように当日在庫として数えられ、カートに入り、販売明細になり、提供終了する。`daily_inventories` / `sale_items` / `additional_orders` / `discontinuation` を素直に共有できていて、ここを分ける理由は無い。

一方、価格と割引では何も束ねていない。

| | 弁当 | サラダ |
| --- | --- | --- |
| 価格 | 通常価格のみ | 通常価格 + セット価格 |
| クーポン | 弁当 1 個につき 1 枚 | 適用できない |
| 売上分析 | 数える | 数えない |
| 価格ルール | セット価格の**トリガー** | 弁当の個数で価格が変わる |

同じ形をしていない。作成経路すら別クラスに分かれている（`Catalogs::BentoCreator` と `Catalogs::SideMenuCreator`）。

さらに、**業務規則が問うのは常に「弁当かどうか」だけである。**

```
bento?      → クーポン適用上限、売上分析、セット価格のトリガー
side_menu?  → 陳列（タブ分け）3 箇所 + show_bundle_price? 1 箇所
```

`side_menu?` の唯一の非陳列用例である `Catalogs::Prices::Component#show_bundle_price?` は、`bento?` 側の「セット価格のトリガー」と同じ 1 つの規則の裏表にすぎない ——「弁当を 1 個買うごとに、サラダ 1 個がセット価格になる」。**「サイドメニューである」ことを独立に必要とする業務規則は存在しない。**

同じ歪みが `CatalogPricingRule` にも出ている。`target_catalog` / `price_kind` / `trigger_category` / `max_per_trigger` / `valid_from` を持つ汎用の価格ルールテーブルだが、本番の生成元は `Catalogs::SideMenuCreator#create_pricing_rule!` の 1 箇所だけで、入る値は常に `bundle` / `bento` / `1` である。汎用の生成器 `Catalogs::PricingRuleCreator` に至っては**テストからしか呼ばれていない**。たった 1 つの規則のために汎用ルールエンジンが建っている。

## 決定

### 1. `Catalog` は 1 テーブル + `enum` のまま据え置く

在庫と販売の共有は本物であり、そこを壊さずに価格と割引だけを別の軸へ剥がすのは大手術になる。得られるのは「非対称を素直に表せる」ことだけで、動いている在庫・販売の経路を全部通り直すコストに見合わない。

**`enum` が最初から誤りだったわけではない**。誤りは、在庫と販売の抽象の上に、価格と割引の非対称を後から乗せる場所として `category` を使ったことである。分類子は種別を表す道具であって、業務規則を運ぶ道具ではない。しかし現状それが動いており、区分が 2 つで閉じている限り実害は無い。

### 2. 陳列カテゴリは閉じた 2 値として扱う。直書きを欠陥とみなさない

`bento` / `side_menu` をビューやフォームが名指ししている箇所（差額精算・POS 販売画面・当日在庫登録・`Catalog.category_order`）は、**開かれた集合を取りこぼしているのではなく、閉じた 2 つを列挙している**。動的に組み立て直す変更は、区分が増えるという前提に立った投資であり、その前提は無い。

### 3. 3 つ目の区分が現れたら、差額精算で落とす

`Catalog#category` に 3 つ目の値が入ったときの壊れ方は 1 箇所だけ性質が違う。

| 箇所 | 壊れ方 |
| --- | --- |
| `Catalogs::CreatorFactory` | `InvalidCategoryError`。**うるさく壊れる** |
| `Catalog.category_order` | `in_order_of` の既定 `filter: true` が `WHERE category IN (...)` を付けるため、その商品が全 POS 経路から消える。**目に見える** |
| POS 販売画面 | タブが無く売れない。**目に見える** |
| 当日在庫登録 | タブが無く登録できない。**目に見える** |
| **差額精算** | 数量入力が描画されない → 送信キーが現れない → 「0 個に減った」と読まれる → **ユーザーが触っていない商品が黙って返金される** |

区分を増やす人は、上の 4 つに順に止められながら直していく。差額精算だけがその列の外にいて、直し忘れても何も言わない。そこに 2 段の網を掛ける。

**1 段目は `enum` の隣に置いたテスト**である。`Catalog::DISPLAY_CATEGORIES` と `Catalog.categories.keys` の一致を主張する（`test/models/catalog_test.rb`）。`category` に値を足したその場の `bin/rails test` で落ち、失敗メッセージが下の「結果」節の一覧を指す。実行時の例外は「`enum` を足す **かつ** その商品を作る **かつ** 売る **かつ** 差額精算を開く」の 4 条件が揃わないと発火しないので、第一発見者にはなれない。すり抜けたときの顕れ方も、テストなら CI の赤、実行時例外なら現場で操作している最中の 500 である。

**2 段目が実行時のガード** `Refunds::RefundForm#verify_displayable` で、`UndisplayableCategoryError` を投げる。置き場所は `RefundForm#catalog_lookup`。ここが数量入力の母集合で、`corrected_quantities`（確定経路が読む）と `corrected_items`（描画経路が読む）の**両方がここから派生する**。描画側の `corrected_items` にだけ掛けると、`RefundsController#create` は `corrected_items_for_refunder` しか通らないため素通りし、「確定の前に必ず画面が描画される」という運用上の順序に依存した守りになってしまう。

**判定には `Catalog::DISPLAY_CATEGORIES` を使わない。** `catalog.bento? || catalog.side_menu?` を直接読む。定数を読ませると 2 つの網が**直列**になり、1 段目を通す行為がそのまま 2 段目を開けてしまうからである。区分を増やす人の手順を追うと分かる。

1. `enum` に `dessert: 2` を足す
2. 1 段目のテストが落ちる
3. 失敗メッセージに従って `DISPLAY_CATEGORIES` に `dessert` を足し、緑にする
4. **この時点でガードが `dessert` を通す。**しかし `Pos::Refunds::NewPage::Component#tab_items` は `:bento` / `:side_menu` を直書きしたままなので、デザートのタブは出ない

つまり定数ベースのガードは、この ADR が敵として名指ししている「3 つ目の `enum` 値」に対して**原理的に発火しない**。3 つ目の値が入るときは、必ず定数も一緒に更新されているからである。実際に `enum` と定数の両方に `dessert` を足して差額精算を組むと、例外は出ず `corrected_items` にデザートが居るのにタブは `[:bento, :coupon]` だけになることを確認した。

`bento?` / `side_menu?` は `bento_corrected_items` / `side_menu_corrected_items` と `tab_items` が実際に使っている述語そのものなので、**タブを増やすまで真にならない**。定数を直しただけでは網は開かない。今日の挙動は区分が 2 つで閉じている限り定数版と同値である。

### 4. `CatalogPricingRule` の汎用性は据え置く

規則が 1 つしか無いのに汎用テーブルが建っているのは過剰だが、既に販売と差額精算の価格計算が乗っている。畳む利益より、価格計算を触るリスクが上回る。**次にこのテーブルを見た人が「汎用ルールエンジンがある」と誤解して拡張しないよう、ここに書き残すことで代える。**

## 検討して採らなかった案

- **STI またはテーブル分離** — 在庫と販売の共有が本物なので、分けると `daily_inventories` / `sale_items` / `additional_orders` の参照先が 2 つに割れる。区分が増えない前提でそのリスクを取る理由が無い。
- **陳列カテゴリの動的化**（`corrected_items` に実在する区分からタブを組む）— 開かれた集合という誤った前提に対する投資。#320 が当初提案していた方向で、グリルの結果棄却した。
- **「その他」タブへのフォールバック** — 落ちずに済むが、区分を追加した人が「動いた」と思って通り過ぎる。クーポン上限も売上分析もその商品を無視していることに誰も気づかない。silent を loud に変えるための装置が、また silent に戻る。加えて区分が増えない前提では永久に描画されない死んだ UI になる。

## 結果

- **区分を増やすときに触る箇所**: `Catalog#category` の `enum` と `Catalog::DISPLAY_CATEGORIES`（後者は `Catalog.category_order` の絞り込みだけを支配する。**これを直しても画面は何も増えない**）、`CatalogPricingRule#trigger_category` の `enum`、`Catalogs::CreatorFactory` と `Catalogs::*Creator`、POS 販売画面 / 当日在庫登録 / 差額精算の `tab_items` と ERB の `case`、`Catalogs::CategorySelector::Component`、`ja.enums.catalog.category`。加えて、新しい区分がクーポン適用上限と売上分析に数えられるべきかの業務判断（既定は「弁当ではないので数えない」）。
- **副菜が増えたとき**（味噌汁など）: 区分は増えないが `CONTEXT.md` の「サラダ」が区分名として成り立たなくなる。用語と `side_menu` の対応を見直す必要がある。
- `Catalog::DISPLAY_CATEGORIES` は `Catalog.categories.keys` から導いてはいけない。導くと 3 つ目の値が増えた瞬間に `category_order` の絞り込みが黙って広がる。閉じた集合はリテラルで持つことに意味がある。
- 2 つの網は**並列**であって直列ではない。1 段目は `enum` の編集を、2 段目は「描画できない商品が母集合に居ること」を、それぞれ独立に検出する。片方を通す操作でもう片方が開いてはいけない。
- 差額精算の `verify_displayable` は、区分が 2 つで閉じている限り一度も発火しない。発火したらそれは「上の一覧を直し切っていない」という意味である。
