# frozen_string_literal: true

# テスト環境でのみ使用するエラーハンドリング検証用コントローラー
# Employee::RodauthControllerを継承することで、rescue_from ActiveRecord::RecordNotFoundの
# 認証状態に応じたリダイレクト動作をテストできる
class Employee::TestErrorController < Employee::RodauthController
  def record_not_found
    Employee.find(999_999)
  end
end
