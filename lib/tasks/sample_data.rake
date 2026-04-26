# frozen_string_literal: true

namespace :sample_data do
  desc "売上分析画面の表示確認用サンプルデータを投入（市役所・過去90日分）"
  task sales: :environment do
    rng = Random.new(12345)

    # --- 前提条件チェック ---
    location = Location.find_by(name: "市役所")
    abort "市役所が見つかりません。先に bin/rails db:seed を実行してください" unless location

    bentos = Catalog.available.bento.to_a
    abort "弁当カタログが見つかりません。先に bin/rails db:seed を実行してください" if bentos.empty?

    employee = Employee.first
    abort "従業員が見つかりません。先に bin/rails db:seed を実行してください" unless employee

    salad = Catalog.available.side_menu.first

    # --- 冪等性チェック ---
    existing_count = Sale.at_location(location).count
    if existing_count > 0
      print "市役所の販売データが #{existing_count} 件あります。削除して再作成しますか？ [y/N] "
      unless $stdin.gets&.strip&.downcase == "y"
        abort "中断しました"
      end
      Sale.at_location(location).destroy_all
      puts "既存データを削除しました"
    end

    # --- カタログ・価格の準備 ---
    catalog_prices = {}
    bentos.each do |bento|
      price = bento.price_by_kind(:regular)
      next unless price
      catalog_prices[bento.id] = price
    end

    salad_bundle_price = salad&.price_by_kind(:bundle)
    catalog_prices[salad.id] = salad_bundle_price if salad && salad_bundle_price

    # 価格が設定されている弁当のみ対象
    bentos = bentos.select { |b| catalog_prices.key?(b.id) }
    abort "価格が設定されている弁当がありません" if bentos.empty?

    # 人気商品（上位5種を重み3倍）
    popular = bentos.first(5)
    weighted_bentos = popular * 3 + bentos

    # 曜日係数（月=1, 火=2, ..., 金=5）
    weekday_factors = { 1 => 0.8, 2 => 1.0, 3 => 1.2, 4 => 1.2, 5 => 0.9 }

    # --- データ生成 ---
    total_sales = 0
    total_amount = 0
    staff_count = 0
    business_dates = []

    puts "サンプルデータを生成中..."

    Sale.transaction do
      (90.days.ago.to_date..Date.yesterday).each do |date|
        next if date.saturday? || date.sunday?

        business_dates << date
        factor = weekday_factors[date.cwday] || 1.0
        daily_count = (10 * factor * (0.6 + rng.rand * 0.8)).round.clamp(5, 15)

        daily_count.times do
          customer_type = rng.rand < 0.4 ? :staff : :citizen
          staff_count += 1 if customer_type == :staff

          # 商品選択
          bento = weighted_bentos[rng.rand(weighted_bentos.size)]
          items_data = [{ catalog: bento, quantity: 1 }]

          # 20%の確率でサラダ追加
          if salad && salad_bundle_price && rng.rand < 0.2
            items_data << { catalog: salad, quantity: 1 }
          end

          # 金額計算
          amount = items_data.sum do |item|
            cp = catalog_prices[item[:catalog].id]
            cp.price * item[:quantity]
          end

          # Sale 作成
          hour = 10 + rng.rand(3)
          minute = rng.rand(60)
          sale_datetime = date.in_time_zone.change(hour: hour, min: minute)

          sale = Sale.create!(
            location: location,
            employee: employee,
            sale_datetime: sale_datetime,
            customer_type: customer_type,
            total_amount: amount,
            final_amount: amount,
            status: :completed
          )

          # SaleItem 作成
          items_data.each do |item|
            cp = catalog_prices[item[:catalog].id]
            sale.items.create!(
              catalog: item[:catalog],
              catalog_price: cp,
              quantity: item[:quantity],
              unit_price: cp.price,
              sold_at: sale_datetime
            )
          end

          total_sales += 1
          total_amount += amount
        end
      end
    end

    # --- voided 販売の作成 ---
    void_count = 5 + rng.rand(4) # 5〜8件
    void_dates = business_dates.sample(void_count, random: rng)
    voided = 0

    void_dates.each do |date|
      sale = Sale.at_location(location)
                 .completed
                 .where(sale_datetime: date.beginning_of_day..date.end_of_day)
                 .first
      if sale
        sale.void!(voided_by: employee)
        voided += 1
      end
    end

    # --- 当日分の DailyInventory を生成 ---
    unless location.has_today_inventory?
      InventoryItem = Struct.new(:catalog_id, :stock)
      items = Catalog.available.map { |c| InventoryItem.new(c.id, 6) }
      DailyInventory.bulk_create(location: location, items: items)
      puts "当日分の在庫を登録しました（#{items.size} 商品 × 各6個）"
    end

    # --- サマリー出力 ---
    citizen_count = total_sales - staff_count
    daily_totals = Sale.at_location(location).completed.group("DATE(sale_datetime)").sum(:final_amount)
    best_day = daily_totals.max_by { |_, v| v }
    worst_day = daily_totals.min_by { |_, v| v }

    puts <<~SUMMARY

      === サンプルデータ投入完了 ===
      対象: #{location.name}
      期間: #{90.days.ago.to_date} 〜 #{Date.yesterday} (90日間)
      営業日数: #{business_dates.size}日
      販売件数: #{total_sales}件 (completed: #{total_sales - voided}, voided: #{voided})
      顧客内訳: staff #{staff_count}件 (#{(staff_count * 100.0 / total_sales).round(1)}%), citizen #{citizen_count}件 (#{(citizen_count * 100.0 / total_sales).round(1)}%)
      売上金額: ¥#{total_amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse} (日平均: ¥#{(total_amount / business_dates.size).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse})
      最高日: #{best_day&.first} (¥#{best_day&.last&.to_s&.reverse&.gsub(/(\d{3})(?=\d)/, '\1,')&.reverse})
      最低日: #{worst_day&.first} (¥#{worst_day&.last&.to_s&.reverse&.gsub(/(\d{3})(?=\d)/, '\1,')&.reverse})
    SUMMARY
  end
end
