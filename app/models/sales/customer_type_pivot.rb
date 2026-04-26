# frozen_string_literal: true

module Sales
  # (name, customer_type, quantity) 形式の行を
  # 顧客タイプ別に展開したハッシュ配列に変換するユーティリティ
  module CustomerTypePivot
    private

    # @param rows [Array<Array>] [[name, customer_type_string, quantity], ...]
    # @return [Array<Hash>] [{ catalog_name:, staff_quantity:, citizen_quantity:, total_quantity: }, ...]
    def pivot_by_customer_type(rows)
      grouped = rows.each_with_object(Hash.new { |h, k| h[k] = { staff: 0, citizen: 0 } }) do |(name, ct, qty), hash|
        hash[name][ct.to_sym] = qty.to_i
      end

      grouped.map do |name, counts|
        {
          catalog_name: name,
          staff_quantity: counts[:staff],
          citizen_quantity: counts[:citizen],
          total_quantity: counts[:staff] + counts[:citizen]
        }
      end.sort_by { |row| -row[:total_quantity] }
    end
  end
end
