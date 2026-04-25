class AddUserToShortUrls < ActiveRecord::Migration[8.1]
  def change
    add_reference :short_urls, :user, null: false, foreign_key: true
  end
end
