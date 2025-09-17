Rails.application.routes.draw do
  # Plays
  resources :plays, only: [:index]
  get 'plays/index' # optional, but can be removed since resources :plays covers it

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Morning routes (index + refresh + backfill)
  resources :morning, only: [:index] do
    collection do
      post :refresh
      post :backfill
    end
  end

  # Root path
  root "plays#index"
end
