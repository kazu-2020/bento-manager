# frozen_string_literal: true

class PageHeaderComponentPreview < ViewComponent::Preview
  # @label タイトルのみ
  def title_only
    render(PageHeaderComponent.new(title: "販売先一覧"))
  end

  # @label 新規作成ボタン付き
  def with_new_button
    render(PageHeaderComponent.new(title: "販売先一覧", new_path: "/locations/new"))
  end

  # @label カスタムラベル
  def with_custom_label
    render(PageHeaderComponent.new(
      title: "商品カタログ",
      new_path: "/catalogs/new",
      new_label: "商品を追加"
    ))
  end

  # @param title text
  # @param new_path text
  # @param new_label text
  def with_params(title: "ページタイトル", new_path: "", new_label: "新規登録")
    render(PageHeaderComponent.new(
      title: title,
      new_path: new_path.presence,
      new_label: new_label
    ))
  end
end
