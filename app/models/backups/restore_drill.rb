require "tmpdir"

module Backups
  # 日次のリストア訓練（ADR-0001 決定 5）
  #
  # Litestream が accessory として独立して動く以上、それが死んでも Rails は動き続ける。
  # だからバックアップの健全性は別途確かめる必要がある。確かめる対象は
  # 「プロセスが動いていること」でも「S3 にオブジェクトがあること」でもなく、
  # 「事故ったときに実際に戻せること」であり、代理指標には必ず
  # 「指標は緑なのに実物は壊れている」隙間ができる。だから毎日ほんとうに復元する。
  class RestoreDrill
    DEFAULT_TOLERANCE = 5

    # ハートビートを書いてから復元するまでに置く間。
    #
    # ここで待たずに「今回の分は未着でも正常」と見逃すと、その 1 日分の猶予が
    # そのまま検知の遅れになる。営業終了後に複製が止まった場合、翌日の訓練は
    # 前回のハートビートしか見ないので緑を返し、赤くなるのは翌々日 = 停止から 31 時間後。
    #
    # L0 の同期は 1 秒前後なので 60 秒は二桁分の余裕がある。訓練は 03:00 に
    # 走るため、この待ちが出張販売にぶつかることもない。
    PROPAGATION_WAIT_SECONDS = 60

    def initialize(restorer: LitestreamRestorer.new,
                   check_in: SentryCheckIn.new,
                   tolerance: ENV.fetch("RESTORE_DRILL_TOLERANCE", DEFAULT_TOLERANCE).to_i,
                   propagation_wait: PROPAGATION_WAIT_SECONDS)
      @restorer = restorer
      @check_in = check_in
      @tolerance = tolerance
      @propagation_wait = propagation_wait
    end

    def run
      check_in_id = @check_in.start
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      result = restore_and_verify

      @check_in.finish(
        check_in_id,
        result.passed? ? :ok : :error,
        duration: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      )
      report(result)

      result
    end

    private

    # ブロック付きの mktmpdir は例外で抜けてもディレクトリごと消えるため、
    # 復元の途中で落ちても数 MB の一時ファイルが本番サーバーに溜まらない。
    def restore_and_verify
      # 復元より先に書く。これが復元側に現れるかどうかが、売上が動かない日に
      # 唯一残る手がかりになる。
      heartbeat = Heartbeat.create!
      sleep @propagation_wait

      Dir.mktmpdir("restore-drill") do |dir|
        destination = File.join(dir, "restored.sqlite3")
        @restorer.restore(destination:)

        ReplicaVerification.new(
          restored_path: destination,
          tolerance: @tolerance,
          required_heartbeat_id: heartbeat.id
        ).call
      end
    rescue LitestreamRestorer::RestoreFailed => e
      DrillResult.failure("リストアそのものが失敗した: #{e.message}")
    rescue StandardError => e
      # 例外を握り潰して失敗として扱う。ここで投げ返すと終端のチェックインが送られず、
      # 訓練が失敗したことが max_runtime のタイムアウト（15 分後）まで分からない。
      DrillResult.failure("訓練の実行中に例外が発生した: #{e.class} #{e.message}")
    end

    # 失敗の理由はログにだけ残す。Sentry には Cron Monitor のチェックインしか送らない。
    # 理由を別イベントとしても送ると、1 回の失敗で届く通知が増えるだけで
    # 「このメールは無視してよい」という学習を招く（ADR-0002）。
    # 通知を受けたら `kamal logs | grep Backups::RestoreDrill` で理由を読むこと。
    def report(result)
      if result.passed?
        Rails.logger.info { "[Backups::RestoreDrill] #{result.message}" }
      else
        Rails.logger.error { "[Backups::RestoreDrill] #{result.message}" }
      end
    end
  end
end
