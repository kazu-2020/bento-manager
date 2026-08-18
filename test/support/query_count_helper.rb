# frozen_string_literal: true

# N+1 の回帰を「件数が増えても問い合わせ本数が増えない」という形で検証するためのヘルパー。
#
# 本数そのものを固定値で書くと、無関係な変更（認証まわりの問い合わせが 1 本増える等）で
# 落ちて意味を失う。件数を変えた前後で比べれば、増えたぶんに比例して問い合わせが増える
# 状態＝N+1 だけを捕まえられる。
#
# Rails の assert_queries_match で足りる場面ではそちらを使う。こちらが要るのは、
# 対象の件数を増やして比べる形にしたいときだけ（Rails の SQLCounter はキャッシュ命中を
# 除外するため、同じリクエストを 2 回投げると 0 本になって比較にならない）。
module QueryCountHelper
  # ブロックの問い合わせ本数が、change を実行しても変わらないことを検証する
  #
  # @param change [#call] データを増やす手続き
  # @param message [String] 失敗時のメッセージ
  # @yield 本数を測る対象（リクエストなど）。change の前後で 1 回ずつ実行される
  def assert_queries_unaffected_by(change, message = nil)
    before = count_queries { yield }
    change.call
    after = count_queries { yield }

    assert_equal before, after, message || "データが増えたぶんだけ問い合わせが増えている"
  end

  private

  # ブロック中に組み立てられた SQL の本数を数える（スキーマ取得とトランザクション制御は除く）
  #
  # クエリキャッシュに当たったものも数える。統合テストでは同じリクエストを繰り返すと
  # 2 回目以降が丸ごとキャッシュに乗ってしまい、除外すると常に 0 本になって何も測れない。
  # ここで見たいのは「行数に比例して SQL を組み立てていないか」なので、キャッシュの有無は
  # 問わない。
  #
  # @return [Integer]
  def count_queries
    count = 0
    subscriber = ->(_name, _start, _finish, _id, payload) do
      next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION"

      count += 1
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }

    count
  end
end
