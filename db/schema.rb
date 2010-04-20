# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 72) do

  create_table "amazon_keywords", :force => true do |t|
    t.string   "keywords",   :null => false
    t.datetime "expires_on", :null => false
  end

  create_table "amazon_results", :force => true do |t|
    t.integer  "amazon_keyword_id",                            :null => false
    t.string   "asin",                                         :null => false
    t.string   "title",             :default => "Unknown"
    t.string   "author",            :default => "Unknown"
    t.string   "image_url",         :default => "unknown.jpg"
    t.string   "detail_url",                                   :null => false
    t.string   "price",             :default => "Unknown"
    t.datetime "date_relased"
    t.string   "company",           :default => "Unknown"
  end

  create_table "artist_urls", :force => true do |t|
    t.integer "artist_id",      :null => false
    t.text    "url",            :null => false
    t.text    "normalized_url", :null => false
  end

  add_index "artist_urls", ["artist_id"], :name => "index_artist_urls_on_artist_id"
  add_index "artist_urls", ["normalized_url"], :name => "index_artist_urls_on_normalized_url"
  add_index "artist_urls", ["url"], :name => "index_artist_urls_on_url"

  create_table "artists", :force => true do |t|
    t.integer  "alias_id"
    t.integer  "group_id"
    t.text     "name",       :null => false
    t.datetime "updated_at", :null => false
    t.integer  "updater_id"
    t.integer  "pixiv_id"
  end

  add_index "artists", ["name"], :name => "artists_name_uniq", :unique => true
  add_index "artists", ["pixiv_id"], :name => "index_artists_on_pixiv_id"

  create_table "bans", :force => true do |t|
    t.integer  "user_id",    :null => false
    t.text     "reason",     :null => false
    t.datetime "expires_at", :null => false
    t.integer  "banned_by",  :null => false
  end

  add_index "bans", ["user_id"], :name => "index_bans_on_user_id"

  create_table "coefficients", :id => false, :force => true do |t|
    t.integer "post_id"
    t.string  "color",   :limit => 1
    t.integer "bin"
    t.integer "v"
    t.integer "x"
    t.integer "y"
  end

  create_table "comments", :force => true do |t|
    t.datetime "created_at",                :null => false
    t.integer  "post_id",                   :null => false
    t.integer  "user_id"
    t.text     "body",                      :null => false
    t.string   "ip_addr",    :limit => nil, :null => false
    t.boolean  "is_spam"
  end

  add_index "comments", ["post_id"], :name => "idx_comments__post"

  create_table "dmails", :force => true do |t|
    t.integer  "from_id",                       :null => false
    t.integer  "to_id",                         :null => false
    t.text     "title",                         :null => false
    t.text     "body",                          :null => false
    t.datetime "created_at",                    :null => false
    t.boolean  "has_seen",   :default => false, :null => false
    t.integer  "parent_id"
  end

  add_index "dmails", ["from_id"], :name => "index_dmails_on_from_id"
  add_index "dmails", ["parent_id"], :name => "index_dmails_on_parent_id"
  add_index "dmails", ["to_id"], :name => "index_dmails_on_to_id"

  create_table "favorites", :force => true do |t|
    t.integer  "post_id",    :null => false
    t.integer  "user_id",    :null => false
    t.datetime "created_at", :null => false
  end

  add_index "favorites", ["post_id"], :name => "idx_favorites__post"
  add_index "favorites", ["user_id"], :name => "idx_favorites__user"

  create_table "flagged_post_details", :force => true do |t|
    t.datetime "created_at",  :null => false
    t.integer  "post_id",     :null => false
    t.text     "reason",      :null => false
    t.integer  "user_id",     :null => false
    t.boolean  "is_resolved", :null => false
  end

  add_index "flagged_post_details", ["post_id"], :name => "index_flagged_post_details_on_post_id"

  create_table "flagged_posts", :force => true do |t|
    t.datetime "created_at",                     :null => false
    t.integer  "post_id",                        :null => false
    t.text     "reason",                         :null => false
    t.integer  "user_id"
    t.boolean  "is_resolved", :default => false, :null => false
  end

# Could not dump table "forum_posts" because of following StandardError
#   Unknown type 'tsvector' for column 'text_search_index'

# Could not dump table "note_versions" because of following StandardError
#   Unknown type 'tsvector' for column 'text_search_index'

# Could not dump table "notes" because of following StandardError
#   Unknown type 'tsvector' for column 'text_search_index'

  create_table "pools", :force => true do |t|
    t.text     "name",                           :null => false
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.integer  "user_id",                        :null => false
    t.boolean  "is_public",   :default => false, :null => false
    t.integer  "post_count",  :default => 0,     :null => false
    t.text     "description", :default => "",    :null => false
  end

  add_index "pools", ["user_id"], :name => "pools_user_id_idx"

  create_table "pools_posts", :force => true do |t|
    t.integer "sequence", :default => 0, :null => false
    t.integer "pool_id",                 :null => false
    t.integer "post_id",                 :null => false
  end

  add_index "pools_posts", ["pool_id"], :name => "pools_posts_pool_id_idx"
  add_index "pools_posts", ["post_id"], :name => "pools_posts_post_id_idx"

  create_table "post_tag_histories", :force => true do |t|
    t.integer  "post_id",                   :null => false
    t.text     "tags",                      :null => false
    t.integer  "user_id"
    t.string   "ip_addr",    :limit => nil
    t.datetime "created_at",                :null => false
  end

  add_index "post_tag_histories", ["post_id"], :name => "idx_post_tag_histories__post"

# Could not dump table "posts" because of following StandardError
#   Unknown type 'post_status' for column 'status'

  create_table "posts_tags", :id => false, :force => true do |t|
    t.integer "post_id", :null => false
    t.integer "tag_id",  :null => false
  end

  add_index "posts_tags", ["post_id"], :name => "idx_posts_tags__post"
  add_index "posts_tags", ["tag_id"], :name => "idx_posts_tags__tag"

  create_table "table_data", :id => false, :force => true do |t|
    t.text    "name",      :null => false
    t.integer "row_count", :null => false
  end

  create_table "tag_aliases", :force => true do |t|
    t.text    "name",                          :null => false
    t.integer "alias_id",                      :null => false
    t.boolean "is_pending", :default => false, :null => false
    t.text    "reason",     :default => "",    :null => false
  end

  add_index "tag_aliases", ["name"], :name => "idx_tag_aliases__name", :unique => true

  create_table "tag_implications", :force => true do |t|
    t.integer "consequent_id",                    :null => false
    t.integer "predicate_id",                     :null => false
    t.boolean "is_pending",    :default => false, :null => false
    t.text    "reason",        :default => "",    :null => false
  end

  add_index "tag_implications", ["predicate_id"], :name => "idx_tag_implications__child"
  add_index "tag_implications", ["consequent_id"], :name => "idx_tag_implications__parent"

  create_table "tags", :force => true do |t|
    t.text     "name",                                         :null => false
    t.integer  "post_count",                :default => 0,     :null => false
    t.text     "cached_related",            :default => "[]",  :null => false
    t.datetime "cached_related_expires_on",                    :null => false
    t.integer  "tag_type",                  :default => 0,     :null => false
    t.boolean  "is_ambiguous",              :default => false, :null => false
    t.integer  "safe_post_count",           :default => 0,     :null => false
  end

  add_index "tags", ["name"], :name => "idx_tags__name", :unique => true
  add_index "tags", ["post_count"], :name => "idx_tags__post_count"

  create_table "user_records", :force => true do |t|
    t.integer  "user_id",                       :null => false
    t.integer  "reported_by",                   :null => false
    t.datetime "created_at",                    :null => false
    t.boolean  "is_positive", :default => true, :null => false
    t.text     "body",                          :null => false
  end

  create_table "users", :force => true do |t|
    t.text     "name",                                                        :null => false
    t.text     "password_hash",                                               :null => false
    t.integer  "level",                    :default => 0,                     :null => false
    t.text     "email",                    :default => "",                    :null => false
    t.text     "my_tags",                  :default => "",                    :null => false
    t.integer  "invite_count",             :default => 0,                     :null => false
    t.boolean  "always_resize_images",     :default => false,                 :null => false
    t.integer  "invited_by"
    t.datetime "created_at",                                                  :null => false
    t.datetime "last_logged_in_at",                                           :null => false
    t.datetime "last_forum_topic_read_at", :default => '1960-01-01 00:00:00', :null => false
    t.boolean  "has_mail",                 :default => false,                 :null => false
    t.boolean  "receive_dmails",           :default => false,                 :null => false
    t.text     "blacklisted_tags",         :default => "",                    :null => false
    t.boolean  "show_samples",             :default => true
  end

# Could not dump table "wiki_page_versions" because of following StandardError
#   Unknown type 'tsvector' for column 'text_search_index'

# Could not dump table "wiki_pages" because of following StandardError
#   Unknown type 'tsvector' for column 'text_search_index'

  add_foreign_key "artist_urls", ["artist_id"], "artists", ["id"], :name => "artist_urls_artist_id_fkey"

  add_foreign_key "artists", ["alias_id"], "artists", ["id"], :on_delete => :set_null, :name => "artists_alias_id_fkey"
  add_foreign_key "artists", ["group_id"], "artists", ["id"], :on_delete => :set_null, :name => "artists_group_id_fkey"
  add_foreign_key "artists", ["updater_id"], "users", ["id"], :on_delete => :set_null, :name => "artists_updater_id_fkey"

  add_foreign_key "bans", ["banned_by"], "users", ["id"], :on_delete => :cascade, :name => "bans_banned_by_fkey"
  add_foreign_key "bans", ["user_id"], "users", ["id"], :on_delete => :cascade, :name => "bans_user_id_fkey"

  add_foreign_key "comments", ["post_id"], "posts", ["id"], :on_delete => :cascade, :name => "fk_comments__post"
  add_foreign_key "comments", ["user_id"], "users", ["id"], :on_delete => :set_null, :name => "fk_comments__user"

  add_foreign_key "dmails", ["from_id"], "users", ["id"], :on_delete => :cascade, :name => "dmails_from_id_fkey"
  add_foreign_key "dmails", ["parent_id"], "dmails", ["id"], :name => "dmails_parent_id_fkey"
  add_foreign_key "dmails", ["to_id"], "users", ["id"], :on_delete => :cascade, :name => "dmails_to_id_fkey"

  add_foreign_key "favorites", ["post_id"], "posts", ["id"], :on_delete => :cascade, :name => "fk_favorites__post "
  add_foreign_key "favorites", ["user_id"], "users", ["id"], :on_delete => :cascade, :name => "fk_favorites__user"

  add_foreign_key "flagged_post_details", ["post_id"], "posts", ["id"], :name => "flagged_post_details_post_id_fkey"
  add_foreign_key "flagged_post_details", ["user_id"], "users", ["id"], :name => "flagged_post_details_user_id_fkey"

  add_foreign_key "flagged_posts", ["user_id"], "users", ["id"], :on_delete => :cascade, :name => "flagged_posts_user_id_fkey"

  add_foreign_key "pools", ["user_id"], "users", ["id"], :on_delete => :cascade, :name => "pools_user_id_fkey"

  add_foreign_key "pools_posts", ["pool_id"], "pools", ["id"], :on_delete => :cascade, :name => "pools_posts_pool_id_fkey"
  add_foreign_key "pools_posts", ["post_id"], "posts", ["id"], :on_delete => :cascade, :name => "pools_posts_post_id_fkey"

  add_foreign_key "post_tag_histories", ["user_id"], "users", ["id"], :on_delete => :set_null, :name => "post_tag_histories_user_id_fkey"

  add_foreign_key "posts_tags", ["tag_id"], "tags", ["id"], :on_delete => :cascade, :name => "fk_posts_tags__tag"

  add_foreign_key "tag_aliases", ["alias_id"], "tags", ["id"], :on_delete => :cascade, :name => "fk_tag_aliases__alias"

  add_foreign_key "tag_implications", ["predicate_id"], "tags", ["id"], :on_delete => :cascade, :name => "fk_tag_implications__child"
  add_foreign_key "tag_implications", ["consequent_id"], "tags", ["id"], :on_delete => :cascade, :name => "fk_tag_implications__parent"

  add_foreign_key "user_records", ["reported_by"], "users", ["id"], :on_delete => :cascade, :name => "user_records_reported_by_fkey"
  add_foreign_key "user_records", ["user_id"], "users", ["id"], :on_delete => :cascade, :name => "user_records_user_id_fkey"

end
