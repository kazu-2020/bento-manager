# frozen_string_literal: true

# POS の画面は稼働中（active）の拠点でしか開けない、というポリシーを 1 箇所に集約する。
#
# 各コントローラーに `Location.active.find` を手書きすると、`.active` を書き忘れても
# 例外は出ない。取引を停止した拠点の在庫登録や販売の画面が静かに開いて、そのまま
# 売れてしまう。before_action ごとここに持たせて、書き忘れる余地を無くしている。
#
# 非 POS の SalesAnalysesController / SalesHistoriesController は LocationFindable を
# 使う。あちらは素の `Location.find` で、拠点の指定が無ければ display_order.first に
# 落とすのが目的なので、POS から呼ぶと停止中の拠点が開く
module PosLocationScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_location
  end

  private

  def set_location
    @location = Location.active.find(params[location_param_key])
  end

  # ネストした POS の画面はすべて :location_id。拠点そのものがリソースになる
  # Pos::LocationsController だけが :id で上書きする
  def location_param_key
    :location_id
  end
end
