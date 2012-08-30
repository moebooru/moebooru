class AddUpdatedAtToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :updated_at, :timestamp
  end
end
