# frozen_string_literal: true

class CatalogsController < ApplicationController
  before_action :set_catalog, only: %i[show edit update destroy]

  def index
    @catalogs = Catalog.all
  end

  def show
  end

  def new
    @catalog = Catalog.new

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @creator = Catalogs::Creator.new(catalog_create_params)

    respond_to do |format|
      if @creator.valid?
        @creator.create!
        @catalogs = Catalog.all
        format.turbo_stream
        format.html { redirect_to catalogs_path, notice: t("catalogs.create.success") }
      else
        @errors = @creator.errors
        @selected_category = catalog_create_params[:category]
        @catalog = Catalog.new(catalog_create_params.slice(:name, :category, :description))
        @catalog.errors.merge!(@creator.errors)
        format.turbo_stream { render :new, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
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
    @catalog = Catalog.find(params[:id])
  end

  def catalog_params
    params.require(:catalog).permit(:name, :category, :description)
  end

  def catalog_create_params
    params.require(:catalog).permit(:name, :category, :description, :regular_price, :bundle_price)
  end
end
