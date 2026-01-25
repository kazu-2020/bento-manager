# frozen_string_literal: true

class DiscountsController < ApplicationController
  before_action :set_discount, only: %i[show edit update]

  def index
    @discounts = Discount.preload(:discountable).order(created_at: :desc)
  end

  def show
  end

  def new
    @discount = Discount.new(valid_from: Date.current)
    @discount.discountable = Coupon.new
  end

  def create
    @discount = Discount.new(discount_params.except(:discountable_attributes))
    @discount.discountable = Coupon.new(discount_params[:discountable_attributes])

    if @discount.save
      @discounts = Discount.preload(:discountable).order(created_at: :desc)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # 有効期間のみ編集可能（名前・クーポン情報は新規作成で対応）
  def edit
    render Discounts::BasicInfoForm::Component.new(discount: @discount)
  end

  def update
    if @discount.update(update_params)
      render :update, formats: :turbo_stream
    else
      render turbo_stream: turbo_stream.replace(
        Discounts::BasicInfo::Component::FRAME_ID,
        Discounts::BasicInfoForm::Component.new(discount: @discount)
      ), status: :unprocessable_entity
    end
  end

  private

  def set_discount
    @discount = Discount.preload(:discountable).find(params[:id])
  end

  # 新規作成時のパラメータ（全項目）
  def discount_params
    params.require(:discount).permit(
      :name, :valid_from, :valid_until,
      discountable_attributes: [ :id, :description, :amount_per_unit, :max_per_bento_quantity ]
    )
  end

  # 更新時のパラメータ（有効期間のみ）
  def update_params
    params.require(:discount).permit(:valid_from, :valid_until)
  end
end
