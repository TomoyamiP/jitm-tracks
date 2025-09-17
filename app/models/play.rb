class Play < ApplicationRecord
  belongs_to :show, optional: true

  # Scope: all plays for a given program, ignoring blanks
  scope :for_program, ->(program_name) {
    joins(:show)
      .where(shows: { program_name: program_name })
      .where.not(artist: nil, song: nil)
  }
end
