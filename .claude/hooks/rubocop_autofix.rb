#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

input = JSON.parse($stdin.read)
file_path = input.dig("tool_input", "file_path")

exit 0 if file_path.nil? || !file_path.end_with?(".rb")

system("bin/rubocop", "-a", file_path, err: File::NULL)
