# 訓練が復元物から読むのは sales の最大 id と件数だけなので、その 2 つだけを再現すれば足りる。
module RestoredReplicaHelper
  def build_replica(path, ids:, heartbeat_ids: production_heartbeat_ids)
    db = SQLite3::Database.new(path.to_s)
    db.execute("CREATE TABLE sales (id INTEGER PRIMARY KEY)")
    db.execute("CREATE TABLE backup_heartbeats (id INTEGER PRIMARY KEY)")
    db.transaction do
      ids.each { |id| db.execute("INSERT INTO sales (id) VALUES (?)", id) }
      heartbeat_ids.each { |id| db.execute("INSERT INTO backup_heartbeats (id) VALUES (?)", id) }
    end
    db.close
  end

  def build_corrupted_replica(path)
    File.binwrite(path, "this is not a sqlite database")
  end

  def production_sale_ids
    Sale.order(:id).pluck(:id)
  end

  def production_heartbeat_ids
    BackupHeartbeat.order(:id).pluck(:id)
  end

  def advance_production(count)
    count.times do
      create_sale(location: locations(:city_hall), customer_type: :citizen, sale_datetime: Time.current)
    end
  end
end
