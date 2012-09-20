class SetDefaultForUsersShowSamples < ActiveRecord::Migration
  def up
    change_column :users, :show_samples, :boolean, :default => true
  end

  def down
    change_column :users, :show_samples, :boolean
  end
end
