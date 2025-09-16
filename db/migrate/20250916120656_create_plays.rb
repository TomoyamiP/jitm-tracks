class CreatePlays < ActiveRecord::Migration[7.1]
  def change
    create_table :plays do |t|
      t.string :song
      t.string :artist
      t.string :album
      t.string :play_type
      t.datetime :played_at
      t.integer :kexp_play_id
      t.string :thumbnail_uri
      t.string :show_uri
      t.string :program_name
      t.text :host_names

      t.timestamps
    end
  end
end
