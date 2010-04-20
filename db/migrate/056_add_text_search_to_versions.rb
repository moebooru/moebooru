class AddTextSearchToVersions < ActiveRecord::Migration
  def self.up
    execute "alter table note_versions add column text_search_index tsvector"
    execute "alter table wiki_page_versions add column text_search_index tsvector"
  end

  def self.down
    raise IrreversibleMigration
  end
end
