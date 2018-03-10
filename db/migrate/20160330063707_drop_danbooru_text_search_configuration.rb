class DropDanbooruTextSearchConfiguration < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.strip_heredoc
      DROP TEXT SEARCH CONFIGURATION danbooru;
    SQL
  end
end
