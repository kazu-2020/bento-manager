require "test_helper"

# ADR-0003 の決定 1（判定と書き込みを同じトランザクションに閉じ込める）は、
# 書き込みトランザクションが BEGIN IMMEDIATE で開かれることに乗っている。
# ここが deferred に変わると、2 つのリクエストが同時に読んでから書けるように
# なり、二重返金（#244）が再発する。
#
# この前提は database.yml ではなく activerecord の実装
# （sqlite3/database_statements.rb の begin_db_transaction が :immediate を
# ハードコードしている）に埋まっているため、Rails を上げたときに静かに
# 外れうる。ADR のコメントではなくここで検知する。
class SqliteTransactionModeTest < ActiveSupport::TestCase
  # 実際に BEGIN を発行させる必要がある。テスト自身のトランザクションの中では
  # SAVEPOINT になってしまうため、このクラスだけ切る（読み取りしかしない）
  self.use_transactional_tests = false

  test "書き込みトランザクションは BEGIN IMMEDIATE で開かれる" do
    statements = capture_transaction_statements do
      Sale.transaction { Sale.first }
    end

    assert_includes statements, "BEGIN immediate TRANSACTION",
      "Rails が書き込みトランザクションを IMMEDIATE で開かなくなった。" \
      "ADR-0003 の決定 1 と、それに依存する Sale#void! / DailyInventory の在庫増減を見直すこと。" \
      "発行された文: #{statements.inspect}"
  end

  private

  def capture_transaction_statements(&block)
    statements = []
    subscriber = ->(_name, _start, _finish, _id, payload) do
      statements << payload[:sql] if payload[:name] == "TRANSACTION"
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &block)
    statements
  end
end
