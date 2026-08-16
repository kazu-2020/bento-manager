module Backups
  # 日次リストア訓練の Sentry Cron Monitor へのチェックイン
  #
  # monitor そのものは Terraform が所有している（infra/terraform/sentry.tf）。
  # チェックインに monitor_config を添えると設定が二重管理になり、次の apply で
  # drift が出て往復するため、slug だけを送る。
  class SentryCheckIn
    SLUG = "litestream-restore-drill".freeze

    def initialize(slug: SLUG)
      @slug = slug
    end

    # 開始時の in_progress を省いてはならない。Sentry の max_runtime_minutes は
    # 「in_progress のチェックインがタイムアウト扱いになるまでの分数」であり、
    # 終端だけを送る実装では働かない。訓練が最も失敗しやすいのは litestream restore の
    # ネットワーク待ちでハングする形で、そこを取りこぼすと検知が
    # max_runtime の 15 分ではなく checkin_margin の 60 分まで遅れる。
    #
    # @return [String, nil] チェックイン ID（Sentry 未初期化時は nil）
    def start
      Sentry.capture_check_in(@slug, :in_progress)
    end

    # @param check_in_id [String, nil] start が返した ID
    # @param status [Symbol] :ok または :error
    # @param duration [Float] 訓練の所要秒数
    def finish(check_in_id, status, duration:)
      Sentry.capture_check_in(@slug, status, check_in_id:, duration:)
    end
  end
end
