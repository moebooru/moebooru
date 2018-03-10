class AddFtsToComments < ActiveRecord::Migration[5.1]
  def self.up
    execute "alter table comments add column text_search_index tsvector"
    execute "update comments set text_search_index = to_tsvector('english', body)"
    execute "create trigger trg_comment_search_update before insert or update on comments for each row execute procedure tsvector_update_trigger(text_search_index, 'pg_catalog.english', body)"
    execute "create index comments_text_search_idx on comments using gin(text_search_index)"
  end

  def self.down
    execute "drop trigger trg_comment_search_update on comments"
    execute "alter table comments drop column text_search_index"
  end
end
