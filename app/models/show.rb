class Show < ApplicationRecord
  has_many :plays, dependent: :nullify
end
