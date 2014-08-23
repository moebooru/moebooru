class AddShowAdvancedEditing < ActiveRecord::Migration
  def self.up
    add_column :users, :show_advanced_editing, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :show_advanced_editing
  end
end
