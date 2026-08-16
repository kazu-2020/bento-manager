require "open3"

module Backups
  # 復元は設定内の path に一致する db を探すため、config/litestream.yml の path と
  # database.yml の production primary が一致していることが前提になっている。
  class LitestreamRestorer
    class RestoreFailed < StandardError; end

    CONFIG_PATH = "config/litestream.yml".freeze

    # 訓練は Solid Queue の recurring task として Puma プロセス内で動く
    # （SOLID_QUEUE_IN_PUMA）。S3 が無応答のまま待ち続けるとワーカースレッドが
    # 1 本占有されたままになり、翌日以降の訓練も含めて動かなくなる。
    # Sentry 側の max_runtime（15 分）は検知であって停止ではないので、自分で打ち切る。
    TIMEOUT_SECONDS = 600

    # 子プロセスの終了後に出力を読み切るまでの上限。孫プロセスが pipe の書き込み端を
    # 握っていると EOF が来ないため、ここに上限が無いと TIMEOUT_SECONDS の意味が消える。
    OUTPUT_READ_TIMEOUT_SECONDS = 10

    def restore(destination:)
      Open3.popen2e(
        "litestream", "restore",
        "-config", Rails.root.join(CONFIG_PATH).to_s,
        "-o", destination.to_s,
        database_path.to_s
      ) do |stdin, output, wait_thread|
        stdin.close

        # 出力は別スレッドで読み続ける。読まずに終了だけ待つと、litestream が
        # pipe の容量を超えて書いた時点で子プロセスが書き込みでブロックし、
        # 終了待ちが解けないまま上のタイムアウトまで進む。本当は正常に動いていたのに
        # 「打ち切った」と報告することになる。
        reader = Thread.new { output.read }

        unless wait_thread.join(TIMEOUT_SECONDS)
          # 判定の直後に子が自然終了して回収済みだと kill は ESRCH を投げる。
          # 素通しすると失敗理由が「打ち切った」ではなく無関係な OS エラーに化ける。
          begin
            Process.kill("KILL", wait_thread.pid)
          rescue Errno::ESRCH
            nil
          end
          reader.kill
          reader.join
          raise RestoreFailed, "#{TIMEOUT_SECONDS} 秒で終わらなかったため打ち切った"
        end

        status = wait_thread.value
        # 成功時も必ず読み切る。ここを通さないと、孫プロセスが書き込み端を握って
        # reader がブロックしたまま popen2e の ensure に入り、pipe が閉じられた
        # 拍子に IOError で死ぬ。訓練の理由はログにしか残らない以上、成功した夜に
        # 無関係な例外が流れる余地を残さない。
        output = read_output(reader)

        raise RestoreFailed, failure_message(status, output) unless status.success?
      end
    end

    private

    def read_output(reader)
      return reader.value if reader.join(OUTPUT_READ_TIMEOUT_SECONDS)

      reader.kill
      nil
    end

    # litestream は何も出力せずに落ちることがある。理由をログにしか残さない設計
    # （RestoreDrill#report）なので、出力が空でも終了コードだけは必ず残す。
    def failure_message(status, output)
      reason = output.to_s.strip
      how = status.signaled? ? "シグナル #{status.termsig} で終了" : "終了コード #{status.exitstatus}"

      reason.empty? ? how : "#{how}: #{reason}"
    end

    def database_path
      Rails.root.join(ActiveRecord::Base.connection_db_config.database)
    end
  end
end
