require "test_helper"

class Backups::RestoreDrillTest < ActiveSupport::TestCase
  fixtures :locations, :employees

  include SaleTestHelper
  include RestoredReplicaHelper

  # litestream は外部プロセス、Sentry は外部 API。古典学派スタイルの例外としてここだけ差し替える。
  class FakeRestorer
    attr_reader :destination

    def initialize(&restore)
      @restore = restore
    end

    def restore(destination:)
      @destination = destination
      @restore.call(destination)
    end
  end

  class RecordingCheckIn
    CHECK_IN_ID = "check-in-id".freeze

    attr_reader :statuses, :finished_check_in_id, :duration

    def initialize
      @statuses = []
    end

    def start
      @statuses << :in_progress
      CHECK_IN_ID
    end

    def finish(check_in_id, status, duration:)
      @statuses << status
      @finished_check_in_id = check_in_id
      @duration = duration
    end
  end

  setup do
    @check_in = RecordingCheckIn.new
  end

  test "訓練は開始時に in_progress を送り、判定後に同じチェックインを結果で閉じる" do
    drill = build_drill { |destination| build_replica(destination, ids: production_sale_ids) }

    result = drill.run

    assert_predicate result, :passed?
    assert_equal [ :in_progress, :ok ], @check_in.statuses
    assert_equal RecordingCheckIn::CHECK_IN_ID, @check_in.finished_check_in_id
    assert_operator @check_in.duration, :>, 0
  end

  test "訓練は実行のたびに本番へハートビートを 1 つ残す" do
    drill = build_drill { |destination| build_replica(destination, ids: production_sale_ids) }

    assert_difference "Backups::Heartbeat.count", 1 do
      assert_predicate drill.run, :passed?
    end
  end

  test "復元したコピーが検証に落ちると訓練は失敗としてチェックインする" do
    drill = build_drill { |destination| build_corrupted_replica(destination) }

    result = drill.run

    refute_predicate result, :passed?
    assert_equal [ :in_progress, :error ], @check_in.statuses
  end

  test "リストアそのものが失敗しても訓練は失敗としてチェックインする" do
    drill = build_drill { raise Backups::LitestreamRestorer::RestoreFailed, "connection refused" }

    result = drill.run

    refute_predicate result, :passed?
    assert_equal [ :in_progress, :error ], @check_in.statuses
    assert_match(/connection refused/, result.message)
  end

  test "訓練は成功しても失敗しても一時ファイルを残さない" do
    succeeding = FakeRestorer.new { |destination| build_replica(destination, ids: production_sale_ids) }
    failing = FakeRestorer.new { raise Backups::LitestreamRestorer::RestoreFailed, "boom" }

    [ succeeding, failing ].each do |restorer|
      Backups::RestoreDrill.new(restorer:, check_in: RecordingCheckIn.new, tolerance: 5).run

      refute_path_exists restorer.destination
      refute_path_exists File.dirname(restorer.destination)
    end
  end

  private

  def build_drill(&restore)
    Backups::RestoreDrill.new(restorer: FakeRestorer.new(&restore), check_in: @check_in, tolerance: 5)
  end
end
