class CreateShortUrls < ActiveRecord::Migration[8.1]
  def change
    create_table :short_urls do |t|
      t.string :slug, null: false
      t.references :target_url, null: false, foreign_key: true, index: true
      t.integer :visits_count, null: false, default: 0

      t.timestamps
    end

    add_index :short_urls, :slug, unique: true
  end
end
