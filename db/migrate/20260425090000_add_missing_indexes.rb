class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    # Unique index prevents find_or_create_by! race conditions on concurrent URL submissions.
    add_index :target_urls, :url, unique: true
    # Composite index supports the dashboard query: ORDER BY created_at DESC WHERE user_id = ?.
    add_index :short_urls, [:user_id, :created_at]
    # Index for batch processing queries that group/filter by IP address.
    add_index :visits, :ip_address
  end
end
