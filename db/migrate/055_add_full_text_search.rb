class AddFullTextSearch < ActiveRecord::Migration
  def self.up
    transaction do
      execute "alter table notes add column text_search_index tsvector"
      execute "update notes set text_search_index = to_tsvector('english', body)"
      execute "create trigger trg_note_search_update before insert or update on notes for each row execute procedure tsvector_update_trigger(text_search_index, 'pg_catalog.english', body)"
      execute "create index notes_text_search_idx on notes using gin(text_search_index)"

      execute "alter table wiki_pages add column text_search_index tsvector"
      execute "update wiki_pages set text_search_index = to_tsvector('english', title || ' ' || body)"
      execute "create trigger trg_wiki_page_search_update before insert or update on wiki_pages for each row execute procedure tsvector_update_trigger(text_search_index, 'pg_catalog.english', title, body)"
      execute "create index wiki_pages_search_idx on wiki_pages using gin(text_search_index)"
      
      execute "alter table forum_posts add column text_search_index tsvector"
      execute "update forum_posts set text_search_index = to_tsvector('english', title || ' ' || body)"
      execute "create trigger trg_forum_post_search_update before insert or update on forum_posts for each row execute procedure tsvector_update_trigger(text_search_index, 'pg_catalog.english', title, body)"
      execute "create index forum_posts_search_idx on forum_posts using gin(text_search_index)"
    end
  end

  def self.down
    raise IrreversibleMigration
  end
end
