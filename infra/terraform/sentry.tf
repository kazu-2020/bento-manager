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
