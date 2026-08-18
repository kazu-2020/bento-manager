class MoveCorrectionLinkToRefunds < ActiveRecord::Migration[8.1]
  # remove_column は SQLite ではテーブル再作成
  # （一時テーブルへコピー → 元を DROP TABLE → 元の名前で復元）に展開される。
  # DDL トランザクションを張ったまま再作成すると DROP TABLE sales の暗黙 DELETE が
  # sale_items / sale_discounts の ON DELETE CASCADE を発火させ、例外も
  # PRAGMA foreign_key_check の警告も出さずに子テーブルが全件消える。
  # 経緯と実測は .claude/rules/migration.md を参照。
  disable_ddl_transaction!

  # 一意にする列。どちらも NULL は重複を許す（SQLite の一意インデックスの仕様）ので、
  # 全額返金で corrected_sale_id が NULL の行が何件あっても衝突しない。
  UNIQUE_COLUMNS = %w[original_sale_id corrected_sale_id].freeze

  # 差額精算の連鎖の出典を refunds に一本化する。
  #
  # 「元の販売 → 修正後の販売」という 1 本の辺は、refunds が両端
  # （original_sale_id, corrected_sale_id）を持って既に記録している。
  # sales.corrected_from_sale_id はその射影でしかなく、同じ事実が 2 か所に
  # 書かれるぶんだけ食い違いうるため、列ごと落とす。
  #
  # あわせて辺の両端を一意にする。Sale#void! が取消済みの販売を弾くため、1 つの販売が
  # 元の販売になれるのは高々 1 回。修正後の販売の側は Sales::Refunder が毎回
  # Sales::Recorder で新しい販売を作るという実装の性質でしか守られておらず、
  # アプリ層のガードが無いぶんこちらのほうが担保を要する。
  # 連鎖（元の販売 → 修正後の販売 → さらに差額精算）で Refund が増えるのは
  # 別々の販売に対してなので、この一意性とは衝突しない。
  #
  # disable_ddl_transaction! の下ではロールバックが無い。途中で落ちた状態から
  # 運用者が再実行できるよう、インデックスの張り替えは if_exists: true で受ける。
  # これが無いと、add_index が SQLITE_BUSY で落ちた次の実行で remove_index が
  # ArgumentError を出し、本当の原因が隠れる。
  def up
    reject_duplicate_sale_references!

    without_losing_rows do
      UNIQUE_COLUMNS.each do |column|
        remove_index :refunds, column, if_exists: true
        add_index :refunds, column, unique: true
      end

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
      restore_correction_links!
      add_foreign_key :sales, :sales, column: :corrected_from_sale_id, on_delete: :restrict

      UNIQUE_COLUMNS.each do |column|
        remove_index :refunds, column, if_exists: true
        add_index :refunds, column
      end
    end
  end

  private

  # 一意インデックスは違反行があると張れない。エラーは重複した値を教えてくれないため、
  # 事前に全件を検査して、是正すべき行を名指しで報告する。
  def reject_duplicate_sale_references!
    duplicates = UNIQUE_COLUMNS.flat_map do |column|
      quoted = quote_column_name(column)
      select_rows(<<~SQL.squish).map { |id, count| "refunds.#{column}=#{id}: #{count} 件" }
        SELECT #{quoted}, COUNT(*) FROM refunds
        WHERE #{quoted} IS NOT NULL
        GROUP BY #{quoted} HAVING COUNT(*) > 1
      SQL
    end

    return if duplicates.empty?

    raise ActiveRecord::MigrationError, <<~MESSAGE
      同じ販売を指す Refund が複数あります。先にデータを是正してください。
      #{duplicates.join("\n")}
    MESSAGE
  end

  # 列だけ戻して値を戻さないと、切り戻した旧コードが全行 nil を読む。
  # Sale#corrected_from_sale は例外を出さず nil を返すため、過去の差額精算の連鎖が
  # 画面からも集計からも静かに消える。refunds が両端を持っているので正確に引き直せる。
  def restore_correction_links!
    execute(<<~SQL.squish)
      UPDATE sales SET corrected_from_sale_id =
        (SELECT r.original_sale_id FROM refunds r WHERE r.corrected_sale_id = sales.id)
      WHERE id IN (SELECT corrected_sale_id FROM refunds WHERE corrected_sale_id IS NOT NULL)
    SQL
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
