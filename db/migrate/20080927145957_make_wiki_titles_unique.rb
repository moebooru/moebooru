class MakeWikiTitlesUnique < ActiveRecord::Migration
  def self.up
    execute "DROP INDEX idx_wiki_pages__title"
    execute "CREATE UNIQUE INDEX idx_wiki_pages__title ON wiki_pages (title)"
  end

  def self.down
    execute "DROP INDEX idx_wiki_pages__title"
    execute "CREATE INDEX idx_wiki_pages__title ON wiki_pages (title)"
  end
end
