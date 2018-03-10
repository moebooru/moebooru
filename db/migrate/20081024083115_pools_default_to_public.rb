class PoolsDefaultToPublic < ActiveRecord::Migration[5.1]
  def self.up
    execute "ALTER TABLE pools ALTER COLUMN is_public SET DEFAULT TRUE"
  end

  def self.down
    execute "ALTER TABLE pools ALTER COLUMN is_public SET DEFAULT FALSE"
  end
end
