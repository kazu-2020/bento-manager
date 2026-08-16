# ADR-0001 決定 5・6 の日次リストア訓練のチェックイン先。
#
# 監視しているのは「プロセスが動いていること」でも「S3 にオブジェクトがあること」でもなく
# 「事故ったときに実際に戻せること」。チェックインが ok になる条件は
# PRAGMA integrity_check の通過と、復元したコピーが本番と一致していることの両方。
#
# この monitor を Terraform が所有するため、実装側はチェックイン時に
# monitor_config を送らないこと。送ると設定が二重管理になり drift が出る。
resource "sentry_cron_monitor" "restore_drill" {
  organization = "matazou"
  project      = "bento-manager"

  name        = "litestream-restore-drill"
  description = "Litestream の日次リストア訓練。失敗はバックアップから復旧できない状態を意味する"

  schedule = {
    crontab = "0 3 * * *"
  }

  # 出張販売の準備時間帯を避ける。DB は数 MB なので VPS への負荷は無視できる
  timezone = "Asia/Tokyo"

  # 訓練の遅延を許容する幅。日次なので 1 時間まで待つ
  checkin_margin_minutes = 60

  # in_progress のチェックインがタイムアウト扱いになるまでの分数。
  # 終端（ok / error）だけを送る実装では機能しないため、訓練は開始時に
  # in_progress を送ること（ADR-0002 決定 7）。実際の所要は数十秒。
  max_runtime_minutes = 15

  # 1 回の失敗も見逃さない。ADR-0001 決定 1 のとおり、バックアップにおける
  # 最大のリスクは「失敗していたことに誰も気づかない」ことである
  failure_issue_threshold = 1
  recovery_threshold      = 1
}

# 訓練が失敗したときに通知を飛ばす。
#
# ADR-0002 決定 7 のとおり、通知先を管理できることが Terraform を選んだ理由である。
# monitor があっても通知が届かなければ、ADR-0001 決定 5 が退けた
# 「指標は緑なのに実物は壊れている」状態そのものになる。
#
# 通知先の故障は静かに起きる。メールアドレスの変更、メンバーの離脱、
# チャンネルの削除。どれもエラーを出さず、ただ届かなくなるだけである。
# コードに置くことで、変更が PR に現れ drift として検出できる。
resource "sentry_alert" "restore_drill" {
  organization = "matazou"
  name         = "リストア訓練の失敗を通知する"

  monitor_ids = [sentry_cron_monitor.restore_drill.id]

  # 同じ issue について再通知する間隔。訓練は日次なので 1 日 1 回で足りる
  frequency_minutes = 1440

  trigger_conditions = [
    # 訓練が失敗すると新しい issue が作られる
    { first_seen_event = {} },

    # 解決済みの失敗が再発した
    { regression_event = {} },
  ]

  action_filters = [
    {
      logic_type = "all"

      # 条件を付けない。訓練の失敗はすべて通知する。
      # 頻度で間引くと「今日は静かだから正常」という誤った安心を生む。

      actions = [
        {
          # target_id を必要としない issue_owners を使う。この monitor に
          # オーナーは設定していないため、実際には fallthrough が効いて
          # 全メンバーに届く。1 人運用では宛先の取り違えが起きない分こちらが堅い。
          email = {
            target_type      = "issue_owners"
            fallthrough_type = "AllMembers"
          }
        },
      ]
    },
  ]
}
