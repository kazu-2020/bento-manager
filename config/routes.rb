Rails.application.routes.draw do
  # Lookbook - ViewComponent preview UI (development only)
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # テスト環境専用ルート（RecordNotFoundハンドリングのテスト用）
  if Rails.env.test?
    scope :admin do
      get "test-record-not-found", to: "test_error#admin_record_not_found"
    end
    scope :employee do
      get "test-record-not-found", to: "test_error#employee_record_not_found"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Admin管理画面
  namespace :admin do
    resources :employees
  end

  # POS（販売員用）
  namespace :pos do
    resources :locations, only: [:index, :show] do
      resources :daily_inventories, only: [:new, :create], module: :locations
      namespace :daily_inventories, module: "locations/daily_inventories" do
        resource :form_state, only: [:create]
      end
      resources :sales, only: [:new], module: :locations
    end
  end

  # 共有リソース（Admin と Employee 両方がアクセス可能）
  resources :locations, except: [ :destroy ]
  resources :discounts, except: [ :destroy ]
  resources :catalogs do
    resource :discontinuation, only: %i[new create], controller: "catalogs/discontinuations"
    resources :catalog_prices, only: %i[edit update], param: :kind
  end

  # Defines the root path route ("/")
  root "home#index"
end
