class PlaysController < ApplicationController
  def index
    @program = params[:program].presence || "The Morning Show" # default target
    @plays   = Play.for_program(@program).order(played_at: :desc).limit(50)

    # Helpful if nothing returns — shows you what program names are available in your DB
    @available_programs = Show.distinct.order(:program_name).pluck(:program_name).compact
  end
end
