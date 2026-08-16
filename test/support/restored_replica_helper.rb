# 訓練が復元物から読むのは sales の最大 id と件数だけなので、その 2 つだけを再現すれば足りる。
module RestoredReplicaHelper
  def build_replica(path, ids:)
    db = SQLite3::Database.new(path.to_s)
    db.execute("CREATE TABLE sales (id INTEGER PRIMARY KEY)")
    db.transaction { ids.each { |id| db.execute("INSERT INTO sales (id) VALUES (?)", id) } }
    db.close
  end

  def build_corrupted_replica(path)
    File.binwrite(path, "this is not a sqlite database")
  end

  def production_sale_ids
    Sale.order(:id).pluck(:id)
  end

  def advance_production(count)
    count.times do
      create_sale(location: locations(:city_hall), customer_type: :citizen, sale_datetime: Time.current)
    end
  end
end
