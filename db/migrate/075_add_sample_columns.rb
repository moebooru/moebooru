class AddSampleColumns < ActiveRecord::Migration
  def self.up
    add_column :posts, :sample_width, :integer
    add_column :posts, :sample_height, :integer
    add_column :users, :show_samples, :boolean
  end

  def self.down
    remove_column :posts, :sample_width
    remove_column :posts, :sample_height
    remove_column :users, :show_samples
  end
end

