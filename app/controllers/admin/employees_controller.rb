# frozen_string_literal: true

class Admin::EmployeesController < Admin::ApplicationController
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
    params.require(:employee).permit(:username, :password)
  end

  def employee_update_params
    # パスワードが空の場合は更新しない
    emp = params.require(:employee)
    if emp[:password].blank?
      emp.permit(:username)
    else
      emp.permit(:username, :password)
    end
  end
end
