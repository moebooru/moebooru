class AddUserFields < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT ''"
    execute "ALTER TABLE users ADD COLUMN tag_blacklist TEXT NOT NULL DEFAULT ''"
    execute "ALTER TABLE users ADD COLUMN user_blacklist TEXT NOT NULL DEFAULT ''"
    execute "ALTER TABLE users ADD COLUMN my_tags TEXT NOT NULL DEFAULT ''"
    execute "ALTER TABLE users ADD COLUMN post_threshold INTEGER NOT NULL DEFAULT -100"
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN email"
    execute "ALTER TABLE users DROP COLUMN tag_blacklist"
    execute "ALTER TABLE users DROP COLUMN user_blacklist"
    execute "ALTER TABLE users DROP COLUMN my_tags"
    execute "ALTER TABLE users DROP COLUMN post_threshold"
  end
end
