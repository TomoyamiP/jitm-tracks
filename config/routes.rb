Rails.application.routes.draw do
  # Plays
  resources :plays, only: [:index]
  get 'plays/index'

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # 🔹 Top-40 Turbo target
  get "morning/top", to: "morning#top", as: :morning_top

  # Morning (index + refresh + backfill)
  resources :morning, only: [:index] do
    collection do
      post :refresh
      post :backfill
    end
  end

  # Root
  root "morning#index"
end
