class AddIndexOnPostSource < ActiveRecord::Migration[5.1]
  def self.up
    add_index :posts, :source
  end

  def self.down
    remove_index :posts, :source
  end
end
