class ImportPostTagHistories < ActiveRecord::Migration
  def self.up
    ActiveRecord::Base.import_post_tag_history
  end

  def self.down
  end
end
