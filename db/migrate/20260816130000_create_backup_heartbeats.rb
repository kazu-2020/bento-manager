class CreateBackupHeartbeats < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_heartbeats, comment: "リストア訓練が本番に残すハートビート。バックアップの健全性検証にのみ使う" do |t|
      t.datetime :created_at, null: false, comment: "訓練が実行された時刻"
    end
  end
end
