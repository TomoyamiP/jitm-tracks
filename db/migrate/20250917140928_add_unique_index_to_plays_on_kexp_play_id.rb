class AddUniqueIndexToPlaysOnKexpPlayId < ActiveRecord::Migration[7.1]
  def change
    # If any accidental dupes slipped in before, this will fail.
    # To be extra safe, we can delete dupes first; see Step 3.
    add_index :plays, :kexp_play_id, unique: true
  end
end
