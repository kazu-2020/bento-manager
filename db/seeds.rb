# frozen_string_literal: true

# Employee アカウント（従業員ログイン用）
puts "Creating Employee..."
employee = Employee.find_or_create_by!(username: "demo") do |e|
  e.password = "password123"
  e.status = :verified
end
puts "  Employee: #{employee.username} (password: password123)"

# Location サンプルデータ
puts "Creating Locations..."

locations_data = [
  { name: "市役所", status: :active },
  { name: "県庁", status: :active },
  { name: "区役所", status: :active },
  { name: "保健センター", status: :active },
  { name: "旧庁舎", status: :inactive }
]

locations_data.each do |data|
  location = Location.find_or_create_by!(name: data[:name]) do |l|
    l.status = data[:status]
  end
  puts "  Location: #{location.name} (#{location.status})"
end

puts "Seed completed!"
