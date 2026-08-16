module Backups
  # リストア訓練が本番に残すハートビート
  #
  # 訓練は業務と無関係に走るため、店が休みでもこの行は増える。
  # 判定でこれを使う理由は ReplicaVerification 側に書いてある。
  class Heartbeat < ApplicationRecord
    self.table_name = "backup_heartbeats"
  end
end
