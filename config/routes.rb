# config/routes.rb
Rails.application.routes.draw do
  # Plays
  resources :plays, only: [:index]
  get 'plays/index'

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Morning (index + refresh + backfill + top)
  resources :morning, only: [:index] do
    collection do
      get  :top          # => morning_top_path
      post :refresh
      post :backfill
    end
  end

  # Root path → Morning#index
  root "morning#index"
end
