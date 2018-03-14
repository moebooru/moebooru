class ImportPostTagHistories < ActiveRecord::Migration[5.1]
  def self.up
    ActiveRecord::Base.import_post_tag_history
  end

  def self.down
  end
end
