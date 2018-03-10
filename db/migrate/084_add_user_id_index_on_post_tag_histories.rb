class AddUserIdIndexOnPostTagHistories < ActiveRecord::Migration[5.1]
  def self.up
    add_index "post_tag_histories", "user_id"
  end

  def self.down
    remove_index "post_tag_histories", "user_id"
  end
end
