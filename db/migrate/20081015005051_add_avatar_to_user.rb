class AddAvatarToUser < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE users ADD COLUMN avatar_post_id INTEGER"
    execute "ALTER TABLE users ADD COLUMN avatar_width REAL"
    execute "ALTER TABLE users ADD COLUMN avatar_height REAL"
    execute "ALTER TABLE users ADD COLUMN avatar_top REAL"
    execute "ALTER TABLE users ADD COLUMN avatar_bottom REAL"
    execute "ALTER TABLE users ADD COLUMN avatar_left REAL"
    execute "ALTER TABLE users ADD COLUMN avatar_right REAL"
    execute "ALTER TABLE users ADD COLUMN avatar_timestamp TIMESTAMP"

    add_foreign_key "users", "avatar_post_id", "posts", "id", :on_delete => :set_null
    add_index :users, :avatar_post_id
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN avatar_post_id"
    execute "ALTER TABLE users DROP COLUMN avatar_top"
    execute "ALTER TABLE users DROP COLUMN avatar_bottom"
    execute "ALTER TABLE users DROP COLUMN avatar_left"
    execute "ALTER TABLE users DROP COLUMN avatar_right"
    execute "ALTER TABLE users DROP COLUMN avatar_width"
    execute "ALTER TABLE users DROP COLUMN avatar_height"
  end
end
