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
  { name: "旧庁舎", status: :inactive }
]

locations_data.each do |data|
  location = Location.find_or_create_by!(name: data[:name]) do |l|
    l.status = data[:status]
  end
  puts "  Location: #{location.name} (#{location.status})"
end

# Bento カタログ
puts "Creating Bento Catalogs..."

bento_data = [
  # 600円
  { name: "日替わりA", price: 600 },
  { name: "日替わりB", price: 600 },
  { name: "ジャンバラヤ", price: 600 },
  { name: "カツどんカレー", price: 600 },
  { name: "鶏と根菜の黒酢あん", price: 600 },
  { name: "グリルチキン", price: 600 },
  { name: "ヘルシー（もろ）", price: 600 },
  { name: "ヘルシー（生姜焼き）", price: 600 },
  { name: "ヘルシー（豆腐ハンバーグ）", price: 600 },
  { name: "トルコライス", price: 600 },
  { name: "トルコライスカレー", price: 600 },
  { name: "ビビンバ丼", price: 600 },
  { name: "牛カルビ丼", price: 600 },
  # 550円
  { name: "炭火焼親子丼", price: 550 },
  { name: "チキン南蛮丼", price: 550 },
  { name: "ドライカレー", price: 550 },
  { name: "きのこロコモコ丼", price: 550 },
  { name: "和風ロコモコ丼", price: 550 },
  { name: "サンドイッチセット", price: 550 },
  { name: "生姜焼き丼", price: 550 },
  { name: "ゴロゴロ野菜とチキンのカレー", price: 550 },
  { name: "ロースカツカレー", price: 550 },
  { name: "ロースかつ丼", price: 550 },
  { name: "牛丼", price: 550 },
  { name: "おろしポン酢牛丼", price: 550 },
  { name: "和風香味ひれかつ丼", price: 550 },
  { name: "香味たれカツ丼", price: 550 },
  { name: "ひれかつ丼", price: 550 },
  { name: "ガパオライス", price: 550 },
  { name: "麻婆ナス丼", price: 550 },
  { name: "麻婆豆腐丼", price: 550 },
  { name: "中華丼", price: 550 },
  { name: "タコライス", price: 550 },
  { name: "カレーオムライス", price: 550 },
  # 500円
  { name: "のり弁当", price: 500 },
  { name: "唐揚げポン酢丼", price: 500 },
  { name: "天丼", price: 500 }
]

bento_data.each do |data|
  next if Catalog.exists?(name: data[:name])

  Catalogs::BentoCreator.new(name: data[:name], regular_price: data[:price]).create!
  puts "  Bento: #{data[:name]} (#{data[:price]}円)"
end

# サイドメニュー カタログ
puts "Creating Side Menu Catalogs..."

side_menu_data = [
  { name: "サラダ", regular_price: 250, bundle_price: 150 }
]

side_menu_data.each do |data|
  next if Catalog.exists?(name: data[:name])

  Catalogs::SideMenuCreator.new(
    name: data[:name],
    regular_price: data[:regular_price],
    bundle_price: data[:bundle_price]
  ).create!
  puts "  Side Menu: #{data[:name]} (通常: #{data[:regular_price]}円, セット: #{data[:bundle_price]}円)"
end

# 割引クーポン
puts "Creating Discount Coupons..."

unless Discount.exists?(name: "50円割引クーポン")
  coupon = Coupon.create!(amount_per_unit: 50)
  Discount.create!(
    discountable: coupon,
    name: "50円割引クーポン",
    valid_from: Date.current
  )
  puts "  Coupon: 50円割引クーポン (1枚あたり50円割引)"
end

puts "Seed completed!"
