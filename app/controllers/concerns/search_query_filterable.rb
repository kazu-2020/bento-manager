# frozen_string_literal: true

# 検索語をパラメータから取り出す。フォームには String か nil しか渡さない。
#
# search_query[]=a のような非スカラーが届くと、フォーム側の `search_query&.strip`
# が NoMethodError で 500 に化ける。検索語として読めないものは検索語として扱わない。
# 確定用と Ghost Form の両方の入口が同じ経路を通るため（ghost-form-pattern.md
# ルール 3）、丸める場所は build_form を持つ concern に揃える
module SearchQueryFilterable
  extend ActiveSupport::Concern

  private

  def search_query_param
    query = params[:search_query]
    query if query.is_a?(String)
  end
end
