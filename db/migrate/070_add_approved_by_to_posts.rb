class AddApprovedByToPosts < ActiveRecord::Migration[5.1]
  def self.up
    add_column :posts, :approved_by, :integer
    add_foreign_key :posts, :approved_by, :users, :id
  end

  def self.down
    remove_column :posts, :approved_by
  end
end
