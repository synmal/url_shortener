class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :short_url, null: false, foreign_key: true, index: true
      t.string :ip_address, null: false
      t.float :latitude
      t.float :longitude
      t.string :country
      t.datetime :visited_at, null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :visits, :processed_at, where: "processed_at IS NULL"
  end
end
