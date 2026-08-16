require "tmpdir"

module Backups
  # 日次のリストア訓練（ADR-0001 決定 5）
  #
  # Litestream が accessory として独立して動く以上、それが死んでも Rails は動き続ける。
  # だからバックアップの健全性は別途確かめる必要がある。確かめる対象は
  # 「プロセスが動いていること」でも「S3 にオブジェクトがあること」でもなく、
  # 「事故ったときに実際に戻せること」であり、代理指標には必ず
  # 「指標は緑なのに実物は壊れている」隙間ができる。だから毎日ほんとうに復元する。
  #
  # config/recurring.yml から日次で起動される。
  class RestoreDrill
    DEFAULT_TOLERANCE = 5

    def initialize(restorer: LitestreamRestorer.new,
                   check_in: SentryCheckIn.new,
                   tolerance: ENV.fetch("RESTORE_DRILL_TOLERANCE", DEFAULT_TOLERANCE).to_i)
      @restorer = restorer
      @check_in = check_in
      @tolerance = tolerance
    end

    # @return [ReplicaVerification::Result]
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
      Dir.mktmpdir("restore-drill") do |dir|
        destination = File.join(dir, "restored.sqlite3")
        @restorer.restore(destination:)

        ReplicaVerification.new(restored_path: destination, tolerance: @tolerance).call
      end
    rescue LitestreamRestorer::RestoreFailed => e
      failure("リストアそのものが失敗した: #{e.message}")
    rescue StandardError => e
      # 例外を握り潰して失敗として扱う。ここで投げ返すと終端のチェックインが送られず、
      # 訓練が失敗したことが max_runtime のタイムアウト（15 分後）まで分からない。
      failure("訓練の実行中に例外が発生した: #{e.class} #{e.message}")
    end

    # Cron Monitor の失敗通知には理由が載らない。運用者が Sentry を開いたときに
    # 何が起きたのか分かるよう、失敗の理由は別途送る。
    def report(result)
      if result.passed?
        Rails.logger.info { "[restore-drill] #{result.message}" }
      else
        Rails.logger.error { "[restore-drill] #{result.message}" }
        Sentry.capture_message("リストア訓練が失敗した: #{result.message}", level: :error)
      end
    end

    def failure(message)
      ReplicaVerification::Result.new(passed: false, message:)
    end
  end
end
