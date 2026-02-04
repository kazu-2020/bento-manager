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
  { name: "日替わりA", kana: "ヒガワリエー", price: 600 },
  { name: "日替わりA(半ライス)", kana: "ヒガワリエーハンライス", price: 600 },
  { name: "日替わりB", kana: "ヒガワリビー", price: 600 },
  { name: "日替わりB(半ライス)", kana: "ヒガワリビーハンライス", price: 600 },
  { name: "ジャンバラヤ", kana: "ジャンバラヤ", price: 600 },
  { name: "カツどんカレー", kana: "カツドンカレー", price: 600 },
  { name: "鶏と根菜の黒酢あん", kana: "トリトコンサイノクロズアン", price: 600 },
  { name: "グリルチキン", kana: "グリルチキン", price: 600 },
  { name: "ヘルシー（もろ）", kana: "ヘルシーモロ", price: 600 },
  { name: "ヘルシー（生姜焼き）", kana: "ヘルシーショウガヤキ", price: 600 },
  { name: "ヘルシー（豆腐ハンバーグ）", kana: "ヘルシートウフハンバーグ", price: 600 },
  { name: "トルコライス", kana: "トルコライス", price: 600 },
  { name: "トルコライスカレー", kana: "トルコライスカレー", price: 600 },
  { name: "ビビンバ丼", kana: "ビビンバドン", price: 600 },
  { name: "牛カルビ丼", kana: "ギュウカルビドン", price: 600 },
  # 550円
  { name: "炭火焼親子丼", kana: "スミビヤキオヤコドン", price: 550 },
  { name: "チキン南蛮丼", kana: "チキンナンバンドン", price: 550 },
  { name: "ドライカレー", kana: "ドライカレー", price: 550 },
  { name: "きのこロコモコ丼", kana: "キノコロコモコドン", price: 550 },
  { name: "和風ロコモコ丼", kana: "ワフウロコモコドン", price: 550 },
  { name: "サンドイッチセット", kana: "サンドイッチセット", price: 550 },
  { name: "生姜焼き丼", kana: "ショウガヤキドン", price: 550 },
  { name: "ゴロゴロ野菜とチキンのカレー", kana: "ゴロゴロヤサイトチキンノカレー", price: 550 },
  { name: "ロースカツカレー", kana: "ロースカツカレー", price: 550 },
  { name: "ロースかつ丼", kana: "ロースカツドン", price: 550 },
  { name: "牛丼", kana: "ギュウドン", price: 550 },
  { name: "おろしポン酢牛丼", kana: "オロシポンズギュウドン", price: 550 },
  { name: "和風香味ひれかつ丼", kana: "ワフウコウミヒレカツドン", price: 550 },
  { name: "香味たれカツ丼", kana: "コウミタレカツドン", price: 550 },
  { name: "ひれかつ丼", kana: "ヒレカツドン", price: 550 },
  { name: "ガパオライス", kana: "ガパオライス", price: 550 },
  { name: "麻婆ナス丼", kana: "マーボーナスドン", price: 550 },
  { name: "麻婆豆腐丼", kana: "マーボードウフドン", price: 550 },
  { name: "中華丼", kana: "チュウカドン", price: 550 },
  { name: "タコライス", kana: "タコライス", price: 550 },
  { name: "カレーオムライス", kana: "カレーオムライス", price: 550 },
  # 500円
  { name: "のり弁当", kana: "ノリベントウ", price: 500 },
  { name: "唐揚げポン酢丼", kana: "カラアゲポンズドン", price: 500 },
  { name: "天丼", kana: "テンドン", price: 500 }
]

bento_data.each do |data|
  next if Catalog.exists?(name: data[:name])

  Catalogs::BentoCreator.new(name: data[:name], kana: data[:kana], regular_price: data[:price]).create!
  puts "  Bento: #{data[:name]} (#{data[:price]}円)"
end

# サイドメニュー カタログ
puts "Creating Side Menu Catalogs..."

side_menu_data = [
  { name: "サラダ", kana: "サラダ", regular_price: 250, bundle_price: 150 }
]

side_menu_data.each do |data|
  next if Catalog.exists?(name: data[:name])

  Catalogs::SideMenuCreator.new(
    name: data[:name],
    kana: data[:kana],
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
