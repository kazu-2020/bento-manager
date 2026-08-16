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

    # @param destination [String] 復元先のパス
    # @raise [RestoreFailed] litestream が非ゼロで終了した場合
    def restore(destination:)
      output, status = Open3.capture2e(
        "litestream", "restore",
        "-config", Rails.root.join(CONFIG_PATH).to_s,
        "-o", destination.to_s,
        database_path.to_s
      )

      raise RestoreFailed, output.strip unless status.success?
    end

    private

    def database_path
      Rails.root.join(ActiveRecord::Base.connection_db_config.database)
    end
  end
end
