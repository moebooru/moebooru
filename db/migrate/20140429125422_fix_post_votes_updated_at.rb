class FixPostVotesUpdatedAt < ActiveRecord::Migration
  def change
    change_column_default :post_votes, :updated_at, nil
  end
end
