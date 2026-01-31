# frozen_string_literal: true

# テスト環境でのみ使用するエラーハンドリング検証用コントローラー
# Admin::RodauthControllerを継承することで、rescue_from ActiveRecord::RecordNotFoundの
# 認証状態に応じたリダイレクト動作をテストできる
class Admin::TestErrorController < Admin::RodauthController
  def record_not_found
    Admin.find(999_999)
  end
end
