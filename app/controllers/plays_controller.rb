class PlaysController < ApplicationController
  def index
    @plays = Play.order(played_at: :desc).limit(20)
  end
end
