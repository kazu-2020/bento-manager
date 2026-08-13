class AddLedgerConstraintsAndForeignKeyActions < ActiveRecord::Migration[8.1]
  # SQLite のテーブル再作成には PRAGMA foreign_keys = OFF が必須だが、この PRAGMA は
  # トランザクション内では no-op になる。DDL トランザクションを無効化しないと
  # DROP TABLE sales の暗黙 DELETE が ON DELETE CASCADE を発火させ、
  # sale_items と sale_discounts が全件消える。例外も PRAGMA foreign_key_check の
  # 警告も出ないため、本番で気づく手段がない。
  #
  # 引き換えにマイグレーション全体の原子性は失われるが、
  # 個々の alter_table は内部で自前のトランザクションを張るので途中状態は生まれない。
  # データ起因の失敗は reject_violating_rows! が事前に弾く。
  disable_ddl_transaction!

  # 金銭・数量カラムに DB レベルの CHECK 制約を追加し、外部キーの削除時挙動を明示する。
  #
  # 制約式はいずれも対応するモデルの numericality バリデーションの写しであり、
  # バリデーションを迂回する経路（update_column / insert_all / 直接 SQL）でも
  # 台帳が壊れないことを保証する。
  #
  # refunds.amount には制約を追加しない。このカラムは金額ではなく符号付きの差額であり、
  # Sales::Refunder が「正=返金、負=追加徴収、0=等価交換」として扱う。
  #
  # NOTE: SQLite は CHECK 制約の追加も外部キーの変更も ALTER TABLE で実現できないため、
  #       Rails は 1 操作ごとにテーブル再作成（一時テーブルへコピー → 元をドロップ →
  #       元の名前で復元）を行う。全体は 1 トランザクション内で実行され、
  #       失敗時は丸ごとロールバックされる。

  # 制約種別 => 演算子。制約名の接尾辞は種別名をそのまま使う。
  KINDS = { positive: ">", non_negative: ">=" }.freeze

  # [テーブル, カラム, 制約種別]
  CHECK_CONSTRAINTS = [
    [ :sale_items,            :quantity,        :positive ],
    [ :sale_items,            :unit_price,      :positive ],
    [ :sale_items,            :line_total,      :positive ],
    [ :catalog_prices,        :price,           :positive ],
    [ :sale_discounts,        :discount_amount, :positive ],
    [ :sale_discounts,        :quantity,        :positive ],
    [ :additional_orders,     :quantity,        :positive ],
    [ :coupons,               :amount_per_unit, :positive ],
    [ :daily_inventories,     :stock,           :non_negative ],
    [ :daily_inventories,     :reserved_stock,  :non_negative ],
    [ :sales,                 :total_amount,    :non_negative ],
    [ :sales,                 :final_amount,    :non_negative ],
    [ :catalog_pricing_rules, :max_per_trigger, :non_negative ]
  ].freeze

  # [テーブル, 参照先, カラム, on_delete]
  FOREIGN_KEYS = [
    [ :sales,                   :employees, :employee_id,            :nullify ],
    [ :sales,                   :employees, :voided_by_employee_id,  :nullify ],
    [ :sales,                   :locations, :location_id,            :restrict ],
    [ :sales,                   :sales,     :corrected_from_sale_id, :restrict ],
    [ :employee_lockouts,       :employees, :id,                     :cascade ],
    [ :employee_login_failures, :employees, :id,                     :cascade ],
    [ :employee_remember_keys,  :employees, :id,                     :cascade ]
  ].freeze

  def up
    reject_violating_rows!

    without_losing_rows do
      CHECK_CONSTRAINTS.each do |table, column, kind|
        add_check_constraint table, expression(column, kind), name: constraint_name(table, column, kind)
      end

      FOREIGN_KEYS.each do |table, to_table, column, on_delete|
        remove_foreign_key table, to_table, column: column
        add_foreign_key table, to_table, column: column, on_delete: on_delete
      end
    end
  end

  def down
    without_losing_rows do
      FOREIGN_KEYS.reverse_each do |table, to_table, column, _on_delete|
        remove_foreign_key table, to_table, column: column
        add_foreign_key table, to_table, column: column
      end

      CHECK_CONSTRAINTS.reverse_each do |table, column, kind|
        remove_check_constraint table, expression(column, kind), name: constraint_name(table, column, kind)
      end
    end
  end

  private

  # 既存データが CHECK 制約に違反しているとテーブル再作成の途中で落ちる。
  # SQLite の DDL はトランザクショナルなので破損はしないが、エラーがどのカラムに
  # 由来するのか分からないため、事前に全件を検査して違反箇所を名指しで報告する。
  def reject_violating_rows!
    violations = CHECK_CONSTRAINTS.filter_map do |table, column, kind|
      count = select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM #{quote_table_name(table)}
        WHERE NOT (#{expression(column, kind)})
      SQL

      "#{table}.#{column} #{expression(column, kind)} に違反: #{count} 行" if count.positive?
    end

    return if violations.empty?

    raise ActiveRecord::MigrationError, <<~MESSAGE
      CHECK 制約を追加できない既存データがあります。先にデータを是正してください。
      #{violations.join("\n")}
    MESSAGE
  end

  # テーブル再作成で子テーブルの行が CASCADE 削除されていないことを検査する。
  # disable_ddl_transaction! が外れると再発し、しかも例外も foreign_key_check の警告も
  # 出ないため、行数の増減を自前で見張るしかない。
  def without_losing_rows
    before = table_row_counts
    yield
    after = table_row_counts

    lost = before.filter_map do |table, count|
      "#{table}: #{count} 行 → #{after[table]} 行" if after[table] < count
    end

    return if lost.empty?

    raise ActiveRecord::MigrationError, <<~MESSAGE
      テーブル再作成で行が失われました。DB を移行前のバックアップから復元してください。
      PRAGMA foreign_keys = OFF がトランザクション内で無効化されている可能性があります。
      #{lost.join("\n")}
    MESSAGE
  end

  def table_row_counts
    (tables - %w[schema_migrations ar_internal_metadata]).index_with do |table|
      select_value("SELECT COUNT(*) FROM #{quote_table_name(table)}").to_i
    end
  end

  def expression(column, kind)
    "#{column} #{KINDS.fetch(kind)} 0"
  end

  def constraint_name(table, column, kind)
    "chk_#{table}_#{column}_#{kind}"
  end
end
