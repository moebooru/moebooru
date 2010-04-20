class AddApproverIdToPosts < ActiveRecord::Migration
  def self.up
    add_column :posts, :approver_id, :integer
    add_foreign_key :posts, :approver_id, :users, :id, :on_delete => :set_null
  end

  def self.down
    remove_column :posts, :approver_id
  end
end
