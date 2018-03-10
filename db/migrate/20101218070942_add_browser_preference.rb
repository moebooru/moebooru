class AddBrowserPreference < ActiveRecord::Migration[5.1]
  def self.up
    add_column :users, :use_browser, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :users, :use_browser
  end
end
