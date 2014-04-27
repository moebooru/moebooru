class RemoveNonVotes < ActiveRecord::Migration
  class PostVote < ActiveRecord::Base
  end

  def up
    PostVote.where('score < 1').delete_all
  end

  def down
    ActiveRecord::IrreversibleMigration
  end
end
