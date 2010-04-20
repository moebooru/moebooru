class UpdateHistories < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.update_all_versioned_tables
  end

  def self.down
  end
end
