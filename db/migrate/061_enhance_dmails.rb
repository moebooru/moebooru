class EnhanceDmails < ActiveRecord::Migration[5.1]
  def self.up
    add_column :dmails, :parent_id, :integer
    add_foreign_key :dmails, :parent_id, :dmails, :id
    add_index :dmails, :parent_id
  end

  def self.down
    remove_column :dmails, :parent_id
  end
end
