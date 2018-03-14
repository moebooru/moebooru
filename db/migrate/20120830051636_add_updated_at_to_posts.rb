class AddUpdatedAtToPosts < ActiveRecord::Migration[5.1]
  def change
    add_column :posts, :updated_at, :timestamp
  end
end
