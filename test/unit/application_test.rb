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
require File.dirname(__FILE__) + "/../test_helper"

class ApplicationTest < ActiveSupport::TestCase
  fixtures :users, :posts
  include CacheHelper
  include ApplicationHelper

  def update_post(post, params = {})
    post.update_attributes({ :updater_user_id => 1, :updater_ip_addr => "127.0.0.1" }.merge(params))
  end

  def get_cache_keys(searches)
    ret = {}

    searches.each do |search|
      result = Post.find_by_sql(Post.generate_sql(search, :order => "p.id DESC"))
      params = { :tags => search }
      key = get_cache_key("post", "index", params)[0]

      ret[search] = key
    end

    ret
  end

  def test_cache_key_expiration
    assert_equal(true, CONFIG["enable_caching"], "Can't test caching with caching disabled")

    # Aggressive caching allows stale cache pages to be used; test with it disabled.
    CONFIG["enable_aggressive_caching"] = false

    pool_id = Pool.create(:name => "dummy", :user_id => 1).id

    tests = [
      {
        # TODO: test fails currently because tags are not expired upon removal
        :setup => { :tags => "pool:#{pool_id}" },
        :changes => [
          { :tags => "abcd efgh" },         # tag addition
          { :tags => "efgh" },              # tag removal
        ],
        :affected_searches => ["abcd", "ab*", "-abcd", "id:1", "pool:#{pool_id}"]
      },
      {
        # s -> e -> s
        :setup => { :rating => "s", :tags => "pool:#{pool_id}" },
        :changes => [
          { :rating => "e" }, { :rating => "s" },

          # rating code path is different for metatags:
          { :tags => "rating:e" }, { :tags => "rating:s" },
        ],
        # changing either way from s -> e -> s should invalidate both s and e
        :affected_searches => ["rating:s", "rating:e", "-rating:s", "-rating:e", "id:1", "pool:#{pool_id}"]
      },
      {
        :setup => { :parent_id => "" },
        :changes => [
          { :tags => "parent:2" },
          { :tags => "parent:" }
        ],
        :affected_searches => ["parent:1", "id:1", "id:2"]
      },
      {
        :setup => { :tags => "-pool:#{pool_id}" },
        :changes => [
          { :tags => "pool:dummy" },
          { :tags => "-pool:dummy" },
          { :tags => "pool:#{pool_id}" },
          { :tags => "-pool:#{pool_id}" },
        ],
        :affected_searches => ["pool:dummy", "pool:#{pool_id}"]
      },
    ]

    message = []
    tests.each do |test|
      before = get_cache_keys(test[:affected_searches])
      update_post(Post.find(1), test[:setup]) if test[:setup]

      # Run each change, and assert that it causes each of affected_searches to
      # use a different cache key.
      test[:changes].each do |change|
        post = Post.find(1)
        update_post(post, change)
        after = get_cache_keys(test[:affected_searches])

        before.each_pair do |key, val|
          assert_not_equal(val, after[key], "Ran <#{change[:tags]}>")
        end

        before = after
      end
    end
  end

  def test_cache_key_limit
    assert_equal(true, CONFIG["enable_caching"], "Can't test caching with caching disabled")

    limit1 = get_cache_key("post", "index", :tags => "", :limit => "100")[0]
    limit2 = get_cache_key("post", "index", :tags => "", :limit => "")[0]
    assert_not_equal(limit1, limit2)
  end
end
