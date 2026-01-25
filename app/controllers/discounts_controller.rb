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
      respond_to do |format|
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @edit_section = params[:section]&.to_sym || :basic_info

    case @edit_section
    when :basic_info
      render Discounts::BasicInfoForm::Component.new(discount: @discount)
    when :coupon_info
      render Discounts::CouponInfoForm::Component.new(discount: @discount)
    end
  end

  def update
    @edit_section = params[:section]&.to_sym || :basic_info

    if @discount.update(discount_params)
      render :update, formats: :turbo_stream
    else
      handle_update_error
    end
  end

  private

  def set_discount
    @discount = Discount.preload(:discountable).find(params[:id])
  end

  def discount_params
    params.require(:discount).permit(
      :name, :valid_from, :valid_until,
      discountable_attributes: [ :id, :description, :amount_per_unit, :max_per_bento_quantity ]
    )
  end

  def handle_update_error
    case @edit_section
    when :basic_info
      render turbo_stream: turbo_stream.replace(
        Discounts::BasicInfo::Component::FRAME_ID,
        Discounts::BasicInfoForm::Component.new(discount: @discount)
      ), status: :unprocessable_entity
    when :coupon_info
      render turbo_stream: turbo_stream.replace(
        Discounts::CouponInfo::Component::FRAME_ID,
        Discounts::CouponInfoForm::Component.new(discount: @discount)
      ), status: :unprocessable_entity
    end
  end
end
