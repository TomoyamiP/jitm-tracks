class Play < ApplicationRecord
  belongs_to :show, optional: true
  scope :for_program, ->(name) { joins(:show).where(shows: { program_name: name }) }
end
