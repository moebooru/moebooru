class UsersRenamePassword < ActiveRecord::Migration[5.1]
  def self.up
    rename_column :users, :password, :password_hash
  end

  def self.down
    rename_column :users, :password_hash, :password
  end
end
