module Backups
  # monitor そのものは Terraform が所有している（infra/terraform/sentry.tf）。
  # チェックインに monitor_config を添えると設定が二重管理になり、次の apply で
  # drift が出て往復するため、slug だけを送る。
  class SentryCheckIn
    # infra/terraform/sentry.tf の sentry_cron_monitor と一致していること
    SLUG = "litestream-restore-drill".freeze

    # 開始時の in_progress を省いてはならない。Sentry の max_runtime_minutes は
    # 「in_progress のチェックインがタイムアウト扱いになるまでの分数」であり、
    # 終端だけを送る実装では働かない。訓練が最も失敗しやすいのは litestream restore の
    # ネットワーク待ちでハングする形で、そこを取りこぼすと検知が
    # max_runtime の 15 分ではなく checkin_margin の 60 分まで遅れる。
    #
    # @return [String, nil] チェックイン ID（Sentry 未初期化時は nil）
    def start
      Sentry.capture_check_in(SLUG, :in_progress)
    end

    def finish(check_in_id, status, duration:)
      Sentry.capture_check_in(SLUG, status, check_in_id:, duration:)
    end
  end
end
