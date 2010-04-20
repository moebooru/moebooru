class AddUserIdIndexOnPostTagHistories < ActiveRecord::Migration
  def self.up
    add_index "post_tag_histories", "user_id"
  end

  def self.down
    remove_index "post_tag_histories", "user_id"
  end
end
