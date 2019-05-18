class AddIndexToPostVotes < ActiveRecord::Migration[5.2]
  def change
    add_index :post_votes, [:user_id, :id]
  end
end
