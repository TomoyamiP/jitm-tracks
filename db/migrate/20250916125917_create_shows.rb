class CreateShows < ActiveRecord::Migration[7.1]
  def change
    create_table :shows do |t|
      t.integer :kexp_show_id
      t.string :uri
      t.string :program_name
      t.text :host_names
      t.datetime :airdate

      t.timestamps
    end
  end
end
