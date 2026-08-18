class MoveCorrectionLinkToRefunds < ActiveRecord::Migration[8.1]
  # remove_column は SQLite ではテーブル再作成
  # （一時テーブルへコピー → 元を DROP TABLE → 元の名前で復元）に展開される。
  # DDL トランザクションを張ったまま再作成すると DROP TABLE sales の暗黙 DELETE が
  # sale_items / sale_discounts の ON DELETE CASCADE を発火させ、例外も
  # PRAGMA foreign_key_check の警告も出さずに子テーブルが全件消える。
  # 経緯と実測は .claude/rules/migration.md を参照。
  disable_ddl_transaction!

  # 差額精算の連鎖の出典を refunds に一本化する。
  #
  # 「元の販売 → 修正後の販売」という 1 本の辺は、refunds が両端
  # （original_sale_id, corrected_sale_id）を持って既に記録している。
  # sales.corrected_from_sale_id はその射影でしかなく、同じ事実が 2 か所に
  # 書かれるぶんだけ食い違いうるため、列ごと落とす。
  #
  # あわせて original_sale_id を一意にする。Sale#void! が取消済みの販売を弾くため、
  # 1 つの販売が元の販売になれるのは高々 1 回であり、その前提を DB 側で担保する。
  # 連鎖（元の販売 → 修正後の販売 → さらに差額精算）で Refund が増えるのは
  # 別々の販売に対してなので、この一意性とは衝突しない。
  #
  # down は列と非一意インデックスを復元するが、削除した corrected_from_sale_id の
  # 値までは戻せない。必要なら refunds から引き直すこと。
  def up
    reject_duplicate_original_sales!

    without_losing_rows do
      remove_index :refunds, :original_sale_id
      add_index :refunds, :original_sale_id, unique: true

      # remove_foreign_key は要らない。SQLite アダプタの remove_column が
      # 削除するカラムの外部キーも一緒に落とすため、先に呼ぶとテーブル再作成が
      # 2 回走り、CASCADE で子テーブルが消える窓を無駄に 1 回増やすことになる
      remove_column :sales, :corrected_from_sale_id
    end
  end

  def down
    without_losing_rows do
      add_column :sales, :corrected_from_sale_id, :integer, comment: "元の販売ID（再販売の場合）"
      add_index :sales, :corrected_from_sale_id
      add_foreign_key :sales, :sales, column: :corrected_from_sale_id, on_delete: :restrict

      remove_index :refunds, :original_sale_id
      add_index :refunds, :original_sale_id
    end
  end

  private

  # 一意インデックスは違反行があると張れない。エラーは重複した値を教えてくれないため、
  # 事前に全件を検査して、是正すべき行を名指しで報告する。
  def reject_duplicate_original_sales!
    duplicates = select_rows(<<~SQL.squish)
      SELECT original_sale_id, COUNT(*) FROM refunds
      GROUP BY original_sale_id HAVING COUNT(*) > 1
    SQL

    return if duplicates.empty?

    raise ActiveRecord::MigrationError, <<~MESSAGE
      同じ販売を元の販売とする Refund が複数あります。先にデータを是正してください。
      #{duplicates.map { |id, count| "original_sale_id=#{id}: #{count} 件" }.join("\n")}
    MESSAGE
  end

  # テーブル再作成で子テーブルの行が CASCADE 削除されていないことを検査する。
  # disable_ddl_transaction! が外れると再発し、しかも例外も警告も出ないため、
  # 行数の増減を自前で見張るしかない。
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
end
