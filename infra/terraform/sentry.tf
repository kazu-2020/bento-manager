# ADR-0001 決定 5・6 の日次リストア訓練のチェックイン先。
#
# 監視しているのは「プロセスが動いていること」でも「S3 にオブジェクトがあること」でもなく
# 「事故ったときに実際に戻せること」。チェックインが ok になる条件は
# PRAGMA integrity_check の通過と、復元したコピーが本番と一致していることの両方。
#
# この monitor を Terraform が所有するため、実装側はチェックイン時に
# monitor_config を送らないこと。送ると設定が二重管理になり drift が出る。
resource "sentry_cron_monitor" "restore_drill" {
  organization = local.sentry_organization
  project      = local.sentry_project

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

# 訓練の失敗を人に届ける。Terraform で管理する理由は ADR-0002 決定 7 を参照。
resource "sentry_alert" "restore_drill" {
  organization = local.sentry_organization
  name         = "リストア訓練の失敗を通知する"

  enabled = true

  monitor_ids = [sentry_cron_monitor.restore_drill.id]

  # 必須属性。同一 issue の再通知間隔だが、下の trigger はいずれも状態遷移でしか
  # 発火せず、同じ issue が 24 時間以内に再発することはない。現状この値が効く場面はない。
  frequency_minutes = 1440

  trigger_conditions = [
    { first_seen_event = {} },

    # recovery_threshold = 1 により、訓練が 1 度成功すると issue は resolved になる。
    # 以降の失敗は新規ではなく regression として届くため、これを外すと
    # 史上初回の失敗しか通知されない。
    { regression_event = {} },
  ]

  # 【既知の穴】連続失敗は初日しか通知されない。
  #
  # 失敗が続く間、同じ unresolved の issue に occurrence が積まれるだけなので
  # first_seen も regression も発火しない。3 日続いても届くのは初日の 1 通で、
  # 2 日目以降の沈黙は正常時と区別できない。初日のメールを取りこぼすと
  # 復旧できない状態が無音のまま続く。
  #
  # 無音になるのは連続失敗の場合だけで、fail → ok → fail と flap するときは
  # regression が拾う。つまり最も危険なパターンでだけ落ちる。
  #
  # trigger を足しても埋まらない。reappeared_event は archive からの復帰を指すので、
  # archive していない issue には効かない。イベントごとに発火する条件は
  # legacy_trigger_conditions にしかなく、プロバイダが deprecation を明記している。
  # 制約として受け入れ、継続中の失敗は Sentry の issue を見に行くこととする（#282）。

  action_filters = [
    {
      # actions と logic_type は必須。conditions を空にすると恒真になる。
      # 訓練は日次で 1 回しか動かないため、件数や頻度での間引きは要らない。
      logic_type = "all"

      actions = [
        {
          # 【注意】このリソースだけでは宛先が固定されていない。
          # issue_owners は Sentry のプロジェクト所有者設定（Terraform 管理外）を
          # 経由して解決され、該当者がいなければ fallthrough で全メンバーに届く。
          # 誰かが所有者ルールを追加すれば、PR も drift も無いまま宛先が変わる。
          # 宛先までコードで固定するには sentry_project_ownership の管理が要る（#282）。
          email = {
            target_type      = "issue_owners"
            fallthrough_type = "AllMembers"
          }
        },
      ]
    },
  ]
}
