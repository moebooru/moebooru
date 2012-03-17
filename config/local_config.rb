# This is the file you use to overwrite the default config values.
# Look at default_config.rb and copy over any settings you want to change.

# You MUST configure these settings for your own server!
CONFIG["app_name"] = "yande.re"
CONFIG["server_host"] = "yande.re"
#CONFIG["server_host"] = "76.73.1.90"
CONFIG["url_base"] = "http://" + CONFIG["server_host"]	# set this to "" to get relative image urls
CONFIG["admin_contact"] = "admin@yande.re"
CONFIG["email_from"] = "moe@yande.re"
CONFIG["image_store"] = :remote_hierarchy
#CONFIG["image_servers"] = ["http://moe.imouto.org", "http://ranka.imouto.org", "http://moe.e-n-m.net"]
CONFIG["image_servers"] = [
#        { :server => "http://mami.imouto.org", :traffic => 0.001 },
#        { :server => "http://haruka.imouto.org", :aliases => ["http://haruka2.imouto.org", "http://haruka3.imouto.org"], :traffic => 1, :previews_only => true, :nozipfile => true },
#        { :server => "http://yusa.imouto.org", :traffic => 4, :nopreview => true },
#        { :server => "http://kobato.imouto.org", :traffic => 4 },
        { :server => "http://ayase.yande.re", :traffic => 4 },
#        { :server => "http://lenin.caltech.edu", :traffic => 0.001, :nozipfile => true },
#        { :server => "http://ranka.imouto.org", :traffic => 1, :previews_only => true } #:nozipfile => true, :nopreview => true }
]
#CONFIG["image_servers"] = ["http://sheryl.imouto.org", "http://ranka.imouto.org", "http://moe.e-n-m.net"]
CONFIG["mirrors"] = [
#        { :user => "moe", :host => "yusa.imouto.org", :data_dir => "/home/moe/moe-live/public/data" },
#        { :user => "moe", :host => "76.73.4.114", :data_dir => "/home/moe/moe-live/public/data" },
#	{ :user => "moe", :host => "69.147.233.170", :data_dir => "/home/moe/data", :previews_only => true },
#        { :user => "moe", :host => "69.147.233.171", :data_dir => "/home/moe/data", :previews_only => true },
#        { :user => "moe", :host => "yande.re", :data_dir => "/home/moe/moe-live/public/data" },
        { :user => "moe", :host => "lenin.caltech.edu", :data_dir => "/home/moe/public/data" },
]
CONFIG["dupe_check_on_upload"] = true
CONFIG["enable_caching"] = true
CONFIG["enable_anonymous_comment_access"] = true
CONFIG["enable_anonymous_safe_post_mode"] = false
CONFIG["use_pretty_image_urls"] = true
CONFIG["download_filename_prefix"] = "yande.re"
CONFIG["member_post_limit"] = 99
CONFIG["member_comment_limit"] = 20
CONFIG["enable_parent_posts"] = true
CONFIG["starting_level"] = 30
CONFIG["memcache_servers"] = ["localhost:11211"]
CONFIG["hide_loli_posts"] = false
CONFIG["enable_reporting"] = true
CONFIG["web_server"] = "lighttpd"
CONFIG["enable_trac"] = false
CONFIG["sample_ratio"] = 1
CONFIG["tag_types"]["Circle"] = 5
CONFIG["tag_types"]["cir"] = 5
CONFIG["tag_types"]["circle"] = 5
CONFIG["tag_types"]["Faults"] = 6
CONFIG["tag_types"]["faults"] = 6
CONFIG["tag_types"]["fault"] = 6
CONFIG["tag_types"]["flt"] = 6
CONFIG["exclude_from_tag_sidebar"] = [0, 6]
CONFIG["local_image_service"] = "yande.re"
CONFIG["default_blacklists"] = [
  "rating:e loli",
  "rating:e shota",
  "extreme_content",
  "rating:e",
  "rating:q",
]
# List of image services available for similar image searching.
CONFIG["image_service_list"] = {
	"danbooru.donmai.us" => "http://iqdb.hanyuu.net/index.xml",
	"yande.re" => "http://iqdb.hanyuu.net/index.xml",
	"konachan.com" => "http://iqdb.hanyuu.net/index.xml",
	"e-shuushuu.net" => "http://iqdb.hanyuu.net/index.xml",
	"gelbooru.com" => "http://iqdb.hanyuu.net/index.xml",
}
# This sets the minimum and maximum value a single user's vote can affect the post's total score.
CONFIG["vote_sum_max"] = 1
CONFIG["vote_sum_min"] = 0
CONFIG["can_see_ads"] = lambda do |user|

user.is_privileged_or_lower?
#false
end

#CONFIG["can_see_post"] = lambda do |user, post|
#   post.rating != "e" || user.is_contributor_or_higher?
#   post.rating != "q" || user.is_contributor_or_higher?
#end

CONFIG["pool_zips"] = true
CONFIG["comment_threshold"] = 9999
CONFIG["image_samples"] = true
CONFIG["jpeg_enable"] = true
CONFIG["max_pending_images"] = 5
CONFIG["min_mpixels"] = 1500000
CONFIG["hide_pending_posts"] = true

#ActionMailer::Base.delivery_method = :smtp
GC.copy_on_write_friendly = true
