# リストア訓練のテスト用に「復元された production.sqlite3」を模したファイルを作る。
#
# 訓練が復元物から読むのは sales の最大 id と件数だけなので、その 2 つだけを再現すれば足りる。
module RestoredReplicaHelper
  # @param path [String] 作成先のパス
  # @param ids [Array<Integer>] 復元物に含まれる sales の id
  def build_replica(path, ids:)
    db = SQLite3::Database.new(path.to_s)
    db.execute("CREATE TABLE sales (id INTEGER PRIMARY KEY)")
    db.transaction { ids.each { |id| db.execute("INSERT INTO sales (id) VALUES (?)", id) } }
    db.close
  end

  # 復元物が壊れている状態（転送の途中で切れた、S3 上のオブジェクトが破損している等）
  def build_corrupted_replica(path)
    File.binwrite(path, "this is not a sqlite database")
  end

  # 訓練が本番として見る状態
  def production_sale_ids
    Sale.order(:id).pluck(:id)
  end

  # レプリケーションが止まった後も本番だけが進んだ状態を作る
  def advance_production(count)
    count.times do
      create_sale(location: locations(:city_hall), customer_type: :citizen, sale_datetime: Time.current)
    end
  end
end
