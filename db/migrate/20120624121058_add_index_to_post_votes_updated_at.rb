class AddIndexToPostVotesUpdatedAt < ActiveRecord::Migration
  def self.up
    add_index :post_votes, :updated_at
  end

  def self.down
    remove_index :post_votes, :updated_at
  end
end
