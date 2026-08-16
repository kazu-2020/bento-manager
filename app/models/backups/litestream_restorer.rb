require "open3"

module Backups
  # `litestream restore` を叩くだけのアダプタ
  #
  # バイナリは app のイメージにも同梱してある（ADR-0001 決定 5）。復元は設定内の
  # path に一致する db を探すため、config/litestream.yml の path と
  # database.yml の production primary が一致していることが前提になっている。
  class LitestreamRestorer
    class RestoreFailed < StandardError; end

    CONFIG_PATH = "config/litestream.yml".freeze

    # 訓練は Solid Queue の recurring task として Puma プロセス内で動く
    # （SOLID_QUEUE_IN_PUMA）。S3 が無応答のまま待ち続けるとワーカースレッドが
    # 1 本占有されたままになり、翌日以降の訓練も含めて動かなくなる。
    # Sentry 側の max_runtime（15 分）は検知であって停止ではないので、自分で打ち切る。
    TIMEOUT_SECONDS = 600

    # @param destination [String] 復元先のパス
    # @raise [RestoreFailed] litestream が非ゼロで終了した、または打ち切られた場合
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
          Process.kill("KILL", wait_thread.pid)
          reader.kill
          raise RestoreFailed, "#{TIMEOUT_SECONDS} 秒で終わらなかったため打ち切った"
        end

        raise RestoreFailed, reader.value.to_s.strip unless wait_thread.value.success?
      end
    end

    private

    def database_path
      Rails.root.join(ActiveRecord::Base.connection_db_config.database)
    end
  end
end
