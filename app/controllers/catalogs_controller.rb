# frozen_string_literal: true

class CatalogsController < ApplicationController
  rescue_from "Catalogs::CreatorFactory::InvalidCategoryError", with: :handle_invalid_category

  before_action :set_catalog, only: %i[show edit update destroy]

  def index
    @current_category = params[:category]&.to_sym
    @catalogs = catalog_scope
                  .eager_load(:discontinuation)
                  .preload(:prices)
                  .order(created_at: :desc)
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
      @creator.create!
      @catalogs = Catalog
                    .eager_load(:discontinuation)
                    .preload(:prices)
                    .order(created_at: :desc)

      respond_to do |format|
        format.turbo_stream
      end
    rescue ActiveRecord::RecordInvalid
      @creator.valid?
      handle_create_error(@creator)
    end
  end

  def edit
  end

  def update
    if @catalog.update(catalog_params)
      redirect_to catalogs_path, notice: t("catalogs.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @catalog.discontinued?
      return redirect_to catalogs_path, alert: t("catalogs.destroy.already_discontinued")
    end

    discontinuation = @catalog.build_discontinuation(
      discontinued_at: Time.current,
      reason: params[:reason].presence || t("catalogs.destroy.default_reason")
    )

    if discontinuation.save
      redirect_to catalogs_path, notice: t("catalogs.destroy.success")
    else
      redirect_to catalogs_path, alert: t("catalogs.destroy.failure")
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
    params.require(:catalog).permit(:name, :category, :description)
  end

  def catalog_create_params
    params.require(:catalog).permit(:name, :category, :description, :regular_price, :bundle_price)
  end

  def handle_create_error(creator)
    @creator = creator
    render :new, status: :unprocessable_entity
  end

  def handle_invalid_category
    render json: { error: I18n.t("catalogs.errors.invalid_category") }, status: :unprocessable_entity
  end

  def catalog_scope
    @current_category ? Catalog.where(category: @current_category) : Catalog.all
  end
end
