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
  end

  def create
    @catalog = Catalog.new(catalog_params)

    if @catalog.save
      redirect_to catalogs_path, notice: t("catalogs.create.success")
    else
      render :new, status: :unprocessable_entity
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
end
