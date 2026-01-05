# frozen_string_literal: true

class EmployeesController < ApplicationController
  before_action :require_admin_authentication
  before_action :set_employee, only: %i[show edit update destroy]

  def index
    @employees = Employee.all
  end

  def show
  end

  def new
    @employee = Employee.new
  end

  def create
    @employee = Employee.new(employee_params)
    @employee.status = :verified # Adminが作成するため、最初から verified 状態

    if @employee.save
      redirect_to admin_employees_path, notice: t("employees.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @employee.update(employee_update_params)
      redirect_to admin_employees_path, notice: t("employees.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @employee.destroy!
    redirect_to admin_employees_path, notice: t("employees.destroy.success")
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(:email, :name, :password, :password_confirmation)
  end

  def employee_update_params
    # パスワードが空の場合は更新しない
    if params[:employee][:password].blank?
      params.require(:employee).permit(:email, :name)
    else
      params.require(:employee).permit(:email, :name, :password, :password_confirmation)
    end
  end
end
