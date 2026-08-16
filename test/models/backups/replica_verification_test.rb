require "test_helper"

class Backups::ReplicaVerificationTest < ActiveSupport::TestCase
  fixtures :locations, :employees

  include SaleTestHelper
  include RestoredReplicaHelper

  setup do
    @dir = Dir.mktmpdir("replica-verification-test")
    @replica_path = File.join(@dir, "restored.sqlite3")
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "何日も売上が無い状態でも、復元したコピーが本番と一致していれば訓練は成功する" do
    create_sale(location: locations(:city_hall), customer_type: :citizen, sale_datetime: 1.year.ago)
    build_replica(@replica_path, ids: production_sale_ids)

    result = verify

    assert_predicate result, :passed?
  end

  test "売上が 1 件も入らない日でも、レプリケーションが止まっていれば訓練は失敗する" do
    replicated_beats = production_heartbeat_ids
    2.times { BackupHeartbeat.beat! }

    # 売上は本番も復元側もまったく同じ。休業日はこれが正常な姿になる
    build_replica(@replica_path, ids: production_sale_ids, heartbeat_ids: replicated_beats)

    result = verify

    refute_predicate result, :passed?
    assert_match(/鼓動/, result.message)
  end

  test "今回の鼓動がまだ複製されていない状態は正常とみなす" do
    replicated_beats = production_heartbeat_ids
    BackupHeartbeat.beat!

    build_replica(@replica_path, ids: production_sale_ids, heartbeat_ids: replicated_beats)

    assert_predicate verify, :passed?
  end

  test "レプリケーションが止まり復元したコピーが本番より遅れていると訓練は失敗する" do
    replicated_ids = production_sale_ids
    advance_production(10)
    build_replica(@replica_path, ids: replicated_ids)

    result = verify(tolerance: 5)

    refute_predicate result, :passed?
    assert_match(/遅れ/, result.message)
  end

  test "訓練の実行中に売上が入っても、遅れが許容差の範囲内なら訓練は成功する" do
    replicated_ids = production_sale_ids
    advance_production(2)
    build_replica(@replica_path, ids: replicated_ids)

    assert_predicate verify(tolerance: 5), :passed?
    refute_predicate verify(tolerance: 1), :passed?
  end

  test "復元したコピーが本番に存在しない売上を含んでいると訓練は失敗する" do
    build_replica(@replica_path, ids: production_sale_ids + [ (Sale.maximum(:id) || 0) + 100 ])

    result = verify

    refute_predicate result, :passed?
    assert_match(/本番より進んで/, result.message)
  end

  test "復元したコピーが壊れていると訓練は失敗する" do
    build_corrupted_replica(@replica_path)

    result = verify

    refute_predicate result, :passed?
    assert_match(/integrity_check/, result.message)
  end

  private

  def verify(tolerance: 5)
    Backups::ReplicaVerification.new(restored_path: @replica_path, tolerance:).call
  end
end
