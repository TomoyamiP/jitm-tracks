class Play < ApplicationRecord
  belongs_to :show, optional: true
end
