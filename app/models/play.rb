class Play < ApplicationRecord
  belongs_to :show, optional: true
  scope :for_program, ->(name) { joins(:show).where(shows: { program_name: name }) }
  # Join with shows to filter by program name
  scope :for_program, ->(program_name) {
    joins(:show).where(shows: { program_name: program_name })
  }
end
