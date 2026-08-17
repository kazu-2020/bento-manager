# 訓練が復元物から読むのは sales の最大 id・件数と、ハートビートの最大 id だけ。
# heartbeat_ids の既定は「本番と完全に一致している」状態で、売上側だけを見たいテストはこれに任せる。
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
    Backups::Heartbeat.order(:id).pluck(:id)
  end

  def advance_production(count)
    count.times do
      create_sale(location: locations(:city_hall), customer_type: :citizen, sale_datetime: Time.current)
    end
  end

  # 本番側の最大 id を採番済みの位置に合わせてから訓練を始める。
  #
  # sales の id は AUTOINCREMENT なので、次の id は「今ある行の最大 + 1」ではなく
  # 「sqlite_sequence の値 + 1」になる。sqlite_sequence はテスト用 DB のファイルに
  # 残り続ける一方、sales フィクスチャはそれを宣言したテストクラスが走るまで投入されない。
  # そのため、このヘルパーを使うクラスが先に走ると「行は 0 件なのに sqlite_sequence だけ
  # 数億」という状態になり、advance_production の 1 件目で最大 id が一気に跳ぶ。
  # 遅れが増えた件数と一致しなくなり、許容差の検証が成立しない。
  # 先に 1 件入れておけば最大 id が採番済みの位置に揃い、以降は本番と同じく連番で進む。
  def align_production_ids
    advance_production(1)
  end
end
