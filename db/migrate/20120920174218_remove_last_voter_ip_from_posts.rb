class RemoveLastVoterIpFromPosts < ActiveRecord::Migration[5.1]
  def up
    remove_column :posts, :last_voter_ip
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
