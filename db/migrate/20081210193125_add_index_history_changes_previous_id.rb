class AddIndexHistoryChangesPreviousId < ActiveRecord::Migration[5.1]
  def self.up
    # We need an index on this for its ON DELETE SET NULL.
    add_index :history_changes, :previous_id
  end

  def self.down
    remove_index :history_changes, :previous_id
  end
end
