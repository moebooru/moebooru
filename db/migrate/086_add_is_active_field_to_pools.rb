class AddIsActiveFieldToPools < ActiveRecord::Migration
  def self.up
    add_column :pools, :is_active, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :pools, :is_active
  end
end
