# frozen_string_literal: true

# system テストのログイン。
#
# test_helper.rb の login_as_employee は ActionDispatch::IntegrationTest の post を
# 使うため system テストからは呼べない。セッションを直接立てるバイパスは作らない。
# 実ブラウザで実際の配線を検証するのが目的なので、本番に無い経路を通しては意味がない。
module SystemLoginHelper
  def login_as_employee(employee, password: "password")
    username = employee.is_a?(Symbol) ? employees(employee).username : employee.username

    visit "/employee/login"
    fill_in "username", with: username
    fill_in "password", with: password
    click_on I18n.t("rodauth.login.button")

    # click_on は遷移の完了を待たない。ここで待たずに visit すると、セッションが
    # 立つ前に次のページを要求してログイン画面へ差し戻される
    assert_text I18n.t("rodauth.login.success")
  end
end
