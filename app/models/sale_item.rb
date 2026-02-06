# 販売時の商品、数量、単価、小計を記録する
# 在庫減算は Sales::Recorder PORO で実行する
class SaleItem < ApplicationRecord
  belongs_to :sale
  belongs_to :catalog
  belongs_to :catalog_price

  # line_total は自動計算値のため、作成後の手動変更を防止
  attr_readonly :line_total

  validates :quantity,   presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :line_total, presence: true, numericality: { greater_than: 0 }
  validates :sold_at,    presence: true

  before_validation :calculate_line_total

  private

  # unit_price と quantity の両方が存在する場合、line_total を計算して設定する
  def calculate_line_total
    return unless unit_price.present? && quantity.present?
    self.line_total = unit_price * quantity
  end
end
