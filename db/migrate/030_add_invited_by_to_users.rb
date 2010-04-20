class AddInvitedByToUsers < ActiveRecord::Migration
  def self.up
    execute "ALTER TABLE users ADD COLUMN invited_by INTEGER"
  end

  def self.down
    execute "ALTER TABLE users DROP COLUMN invited_by"
  end
end
