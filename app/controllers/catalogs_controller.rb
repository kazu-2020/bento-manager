# frozen_string_literal: true

class CatalogsController < ApplicationController
  before_action :set_catalog, only: %i[show edit update destroy]

  def index
    @catalogs = Catalog.all
  end

  def show
  end

  def new
    @selected_category = params[:category]
    @creator = Catalogs::CreatorFactory.build(@selected_category) if @selected_category
    @catalog = Catalog.new

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @selected_category = catalog_create_params[:category]
    @creator = Catalogs::CreatorFactory.build(@selected_category, catalog_create_params.except(:category))

    if @creator.valid?
      @creator.create!
      @catalogs = Catalog.all

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to catalogs_path, notice: t("catalogs.create.success") }
      end
    else
      handle_create_error(@creator.errors)
    end
  rescue ArgumentError
    handle_create_error(build_category_error)
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
    @catalog = Catalog.find(params[:id])
  end

  def catalog_params
    params.require(:catalog).permit(:name, :category, :description)
  end

  def catalog_create_params
    params.require(:catalog).permit(:name, :category, :description, :regular_price, :bundle_price)
  end

  def handle_create_error(errors)
    @errors = errors
    @catalog = Catalog.new(catalog_create_params.slice(:name, :description))

    respond_to do |format|
      format.turbo_stream { render :new, status: :unprocessable_entity }
      format.html { render :new, status: :unprocessable_entity }
    end
  end

  def build_category_error
    errors = ActiveModel::Errors.new(Catalog.new)
    errors.add(:category, :blank)
    errors
  end
end
