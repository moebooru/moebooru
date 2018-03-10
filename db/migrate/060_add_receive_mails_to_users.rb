class AddReceiveMailsToUsers < ActiveRecord::Migration[5.1]
  def self.up
    add_column :users, :receive_dmails, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :receive_dmails
  end
end
