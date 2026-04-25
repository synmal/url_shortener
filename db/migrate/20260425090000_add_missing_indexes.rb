class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :target_urls, :url, unique: true
    add_index :short_urls, [:user_id, :created_at]
    add_index :visits, :ip_address
  end
end
