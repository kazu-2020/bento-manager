#!/usr/bin/env ruby
# frozen_string_literal: true

# PostToolUse (Edit|Write) フック。編集された Ruby ファイルに RuboCop の安全な
# 自動修正をかけ、直しきれなかった offense は exit 2 で Claude に差し戻す。

require "json"
require "open3"

PROJECT_DIR = ENV.fetch("CLAUDE_PROJECT_DIR") { Dir.pwd }
RUBOCOP_BIN = File.join(PROJECT_DIR, "bin", "rubocop")

TARGET_EXTENSIONS = %w[.rb .rake .gemspec .jbuilder].freeze
TARGET_BASENAMES = %w[Gemfile Rakefile Guardfile Capfile config.ru].freeze

def target?(path)
  TARGET_EXTENSIONS.include?(File.extname(path)) ||
    TARGET_BASENAMES.include?(File.basename(path))
end

# bin/rubocop の shebang は `#!/usr/bin/env ruby` なので、PATH 上で先に見つかった
# Ruby (macOS では /usr/bin/ruby 2.6) を掴んで bundler ごと失敗することがある。
# shebang を経由させず、インタプリタを引数として明示して起動する。
def rubocop_command
  mise = ENV["PATH"].to_s
                    .split(File::PATH_SEPARATOR)
                    .map { |dir| File.join(dir, "mise") }
                    .find { |bin| File.executable?(bin) }

  mise ? [ mise, "exec", "--", "ruby", RUBOCOP_BIN ] : [ RUBOCOP_BIN ]
end

begin
  input = JSON.parse($stdin.read)
rescue JSON::ParserError => e
  warn "rubocop_autofix: フックへの入力を JSON として解析できません: #{e.message}"
  exit 1
end

file_path = input.dig("tool_input", "file_path")
exit 0 if file_path.nil? || !target?(file_path) || !File.file?(file_path)

# --force-exclusion: ファイルを明示指定すると AllCops/Exclude が無視されるため、
# tmp/ や vendor/ 配下を編集したときに除外設定を踏み越えないようにする。
command = rubocop_command + [
  "--autocorrect", "--force-exclusion", "--no-color", "--format", "simple", file_path
]
stdout, stderr, status = Open3.capture3(*command, chdir: PROJECT_DIR)

exit 0 if status.success?

# RuboCop の終了コード: 1 = offense が残った / 2 以上 = 実行自体の失敗。
if status.exitstatus == 1
  warn "RuboCop が自動修正できない offense が残っています: #{file_path}"
  warn stdout
else
  warn "rubocop_autofix: RuboCop の実行に失敗しました (exit #{status.exitstatus})"
  warn(stderr.empty? ? stdout : stderr)
end

exit 2
