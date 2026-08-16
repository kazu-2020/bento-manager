module Backups
  # 訓練は「復元して検証する」以外にも「復元そのものが失敗する」形で転ぶため、
  # 検証の結果型ではなく訓練の結果型として置いている。
  DrillResult = Data.define(:passed, :message) do
    def self.success(message) = new(passed: true, message:)
    def self.failure(message) = new(passed: false, message:)

    def passed? = passed
  end
end
