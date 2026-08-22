class CloseEmployeeStatusToVerifiedAndClosed < ActiveRecord::Migration[8.1]
  # change_column_default はテーブル再作成を伴う。employee_lockouts /
  # employee_login_failures / employee_remember_keys が CASCADE で消えるため必須。
  # 機序は 20260813100001_add_ledger_constraints_and_foreign_key_actions.rb を参照。
  disable_ddl_transaction!

  # 従業員のアカウント状態を「有効」と「閉鎖」の 2 つに閉じる（ADR-0007, #365）。
  #
  # データ移行を先に行う。テーブル再作成のコピーは既存の値をそのまま運ぶので、
  # 逆順にすると再作成の負荷を払ったうえで 1 のレコードが残る。
  # Employee.unverified はこの変更で消えるため、モデルを介さず raw SQL で書く。
  def up
    execute "UPDATE employees SET status = 2 WHERE status = 1"
    change_column_default :employees, :status, from: 1, to: 2
    swap_username_index(from: "status IN (1, 2)", to: "status != 3")
  end

  # デフォルト値と述語のみ戻す。どの従業員が unverified だったかは記録していないため
  # データ移行は一方通行だが、戻した先のコードも find_by で状態を素通りさせるので支障がない。
  def down
    swap_username_index(from: "status != 3", to: "status IN (1, 2)")
    change_column_default :employees, :status, from: 2, to: 1
  end

  private

  # 述語を Employee の uniqueness が使う where.not(status: :closed) と同じ式に揃える（ADR-0007）。
  def swap_username_index(from:, to:)
    remove_index :employees, :username, name: "index_employees_on_username", unique: true, where: from
    add_index :employees, :username, name: "index_employees_on_username", unique: true, where: to
  end
end
