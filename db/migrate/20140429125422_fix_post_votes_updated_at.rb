class FixPostVotesUpdatedAt < ActiveRecord::Migration[5.1]
  def change
    change_column_default :post_votes, :updated_at, nil
  end
end
