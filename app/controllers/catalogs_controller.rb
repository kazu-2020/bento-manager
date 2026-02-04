# frozen_string_literal: true

class CatalogsController < ApplicationController
  rescue_from "Catalogs::CreatorFactory::InvalidCategoryError", with: :handle_invalid_category

  before_action :set_catalog, only: %i[show edit update]

  def index
    @current_category = params[:category]&.to_sym || :bento
    @catalogs = catalogs_by_category(@current_category)
  end

  def show
  end

  def new
    @selected_category = params[:category]
    @creator = Catalogs::CreatorFactory.build(@selected_category) if @selected_category
  end

  def create
    @selected_category = catalog_create_params[:category]
    @creator = Catalogs::CreatorFactory.build(@selected_category, catalog_create_params.except(:category))

    begin
      catalog = @creator.create!
      @current_category = catalog.category.to_sym
      @catalogs = catalogs_by_category(@current_category)

      respond_to do |format|
        format.turbo_stream
      end
    rescue ActiveRecord::RecordInvalid
      @creator.valid?
      handle_create_error
    end
  end

  def edit
    render Catalogs::BasicInfoForm::Component.new(catalog: @catalog)
  end

  def update
    if @catalog.update(catalog_params)
      render :update, formats: :turbo_stream
    else
      render turbo_stream: turbo_stream.replace(
        Catalogs::BasicInfo::Component::FRAME_ID,
        Catalogs::BasicInfoForm::Component.new(catalog: @catalog)
      ), status: :unprocessable_entity
    end
  end

  private

  def set_catalog
    @catalog = Catalog
                 .eager_load(:discontinuation)
                 .preload(:prices, :active_pricing_rules)
                 .find(params[:id])
  end

  def catalog_params
    params.require(:catalog).permit(:name, :kana, :category, :description)
  end

  def catalog_create_params
    params.require(:catalog).permit(:name, :kana, :category, :description, :regular_price, :bundle_price)
  end

  def handle_create_error
    render :new, status: :unprocessable_entity
  end

  def handle_invalid_category
    render json: { error: I18n.t("catalogs.errors.invalid_category") }, status: :unprocessable_entity
  end

  def catalogs_by_category(category)
    Catalog
      .where(category: category)
      .eager_load(:discontinuation)
      .preload(:prices)
      .display_order
  end
end
