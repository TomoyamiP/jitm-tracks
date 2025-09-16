class AddShowRefToPlays < ActiveRecord::Migration[7.1]
  def change
    add_reference :plays, :show, foreign_key: true
  end
end
