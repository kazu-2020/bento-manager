# frozen_string_literal: true

# テスト環境でのみ使用するエラーハンドリング検証用コントローラー
# RodauthControllerを継承することで、rescue_from ActiveRecord::RecordNotFoundの
# 認証状態に応じたリダイレクト動作をテストできる
class TestErrorController < RodauthController
  def admin_record_not_found
    Admin.find(999_999)
  end

  def employee_record_not_found
    Employee.find(999_999)
  end
end
