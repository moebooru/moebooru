class AddFullTextIndexOnPostTags < ActiveRecord::Migration
  def self.up
    execute "SET statement_timeout = 0"
    execute "SET search_path = public"

    execute "CREATE OR REPLACE FUNCTION testprs_start(internal, int4)
    RETURNS internal
    AS '$libdir/test_parser'
    LANGUAGE C STRICT"

    execute "CREATE OR REPLACE FUNCTION testprs_getlexeme(internal, internal, internal)
    RETURNS internal
    AS '$libdir/test_parser'
    LANGUAGE C STRICT"

    execute "CREATE OR REPLACE FUNCTION testprs_end(internal)
    RETURNS void
    AS '$libdir/test_parser'
    LANGUAGE C STRICT"

    execute "CREATE OR REPLACE FUNCTION testprs_lextype(internal)
    RETURNS internal
    AS '$libdir/test_parser'
    LANGUAGE C STRICT"

    execute "CREATE TEXT SEARCH PARSER testparser (
        START    = testprs_start,
        GETTOKEN = testprs_getlexeme,
        END      = testprs_end,
        HEADLINE = pg_catalog.prsd_headline,
        LEXTYPES = testprs_lextype
    )"
    
    execute "create text search configuration public.danbooru (PARSER = public.testparser)"
    execute "alter text search configuration public.danbooru add mapping for word with simple"
    execute "set default_text_search_config = 'public.danbooru'"
    
    execute "alter table posts add column tags_index tsvector"
    execute "update posts set tags_index = to_tsvector('danbooru', cached_tags)"
    execute "create index index_posts_on_tags_index on posts using gin(tags_index)"

    execute "create trigger trg_posts_tags_index_update before insert or update on posts for each row execute procedure tsvector_update_trigger(tags_index, 'public.danbooru', cached_tags)"
  end

  def self.down
  end
end
