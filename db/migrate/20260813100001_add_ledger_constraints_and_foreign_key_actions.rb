class AddLedgerConstraintsAndForeignKeyActions < ActiveRecord::Migration[8.1]
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

    CHECK_CONSTRAINTS.each do |table, column, kind|
      add_check_constraint table, expression(column, kind), name: constraint_name(table, column, kind)
    end

    FOREIGN_KEYS.each do |table, to_table, column, on_delete|
      remove_foreign_key table, to_table, column: column
      add_foreign_key table, to_table, column: column, on_delete: on_delete
    end
  end

  def down
    FOREIGN_KEYS.reverse_each do |table, to_table, column, _on_delete|
      remove_foreign_key table, to_table, column: column
      add_foreign_key table, to_table, column: column
    end

    CHECK_CONSTRAINTS.reverse_each do |table, column, kind|
      remove_check_constraint table, expression(column, kind), name: constraint_name(table, column, kind)
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

  def expression(column, kind)
    "#{column} #{KINDS.fetch(kind)} 0"
  end

  def constraint_name(table, column, kind)
    "chk_#{table}_#{column}_#{kind}"
  end
end
