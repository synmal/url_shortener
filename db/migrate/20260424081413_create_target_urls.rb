class CreateTargetUrls < ActiveRecord::Migration[8.1]
  def change
    create_table :target_urls do |t|
      t.string :url, null: false
      t.string :title

      t.timestamps
    end
  end
end
