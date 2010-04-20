class UsersAddCreatedAt < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE users ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT now()"
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN created_at"
  end
end
