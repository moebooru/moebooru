class AddIndexOnPostSource < ActiveRecord::Migration
  def self.up
    add_index :posts, :source
  end

  def self.down
    remove_index :posts, :source
  end
end
