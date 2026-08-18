# frozen_string_literal: true

# 確定済みの販売を Sales::Recorder 経由で用意する。差額精算のテストは「既に確定した
# 販売」から始まるため、明細・クーポン・在庫の減算まで実データで揃っている必要がある。
#
# @location / @employee は各テストの setup で用意しておくこと。
# 生の Sale.create! で組む SaleTestHelper とは用途が違う（あちらは販売履歴の表示用）
module SaleRecordingHelper
  def record_sale(items, discount_quantities: {})
    Sales::Recorder.new.record(
      { location: @location, customer_type: :staff, employee: @employee },
      items,
      discount_quantities: discount_quantities
    )
  end
end
