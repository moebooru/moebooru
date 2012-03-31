class FixUsersNameIndex < ActiveRecord::Migration
  def self.up
    execute 'DROP INDEX "idx_users__name"'
    execute 'CREATE UNIQUE INDEX "idx_users__name" ON "users" (lower("name"))'
  end

  def self.down
    execute 'DROP INDEX "idx_users__name"'
    execute 'CREATE INDEX "idx_users__name" ON "users" (lower("name"))'
  end
end
