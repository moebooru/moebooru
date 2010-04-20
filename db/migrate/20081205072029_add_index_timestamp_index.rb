class AddIndexTimestampIndex < ActiveRecord::Migration
  def self.up
    add_index :posts, :index_timestamp
  end

  def self.down
    remove_index :posts, :index_timestamp
  end
end
