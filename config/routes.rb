Rails.application.routes.draw do
  root "dashboard#index"

  resource :session
  resources :passwords, param: :token
  resources :states, except: :show
  resources :districts, except: :show
  resources :markets, except: :show
  resources :commodity_groups, except: :show
  resources :commodities, except: :show
  resources :varieties, except: :show
  resources :grades, except: :show
  resources :price_units, except: :show
  resources :arrival_units, except: :show
  resources :daily_price_arrival_reports, path: "reports", except: :show do
    collection do
      get :export
      post :import
    end
  end
  resources :cotton_bulletins do
    member do
      get :export
      post :import
    end

    resources :cotton_market_observations, except: %i[index show] do
      collection do
        get :grid
        patch :save_grid
      end
    end
    resources :cotton_seed_rates, except: %i[index show]
    resources :candy_rates, except: %i[index show]
    resources :cotton_regional_comparisons, except: %i[index show]
    resources :cotton_call_performances, except: %i[index show]
  end

  get "arrival-summary" => "daily_arrival_summaries#index", as: :daily_arrival_summaries
  get "cotton-overview" => "cotton_market_overviews#index", as: :cotton_market_overviews

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
