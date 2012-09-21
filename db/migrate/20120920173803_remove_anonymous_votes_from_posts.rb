class RemoveAnonymousVotesFromPosts < ActiveRecord::Migration
  def up
    remove_column :posts, :anonymous_votes
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
