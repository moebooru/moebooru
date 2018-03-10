class RemoveAnonymousVotesFromPosts < ActiveRecord::Migration[5.1]
  def up
    remove_column :posts, :anonymous_votes
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
