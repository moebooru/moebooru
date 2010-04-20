# This is the file you use to overwrite the default config values.
# Look at default_config.rb and copy over any settings you want to change.

# You MUST configure these settings for your own server!
CONFIG["app_name"] = "moe.imouto"
CONFIG["server_host"] = "moe.imouto.org"
#CONFIG["server_host"] = "76.73.1.90"
CONFIG["url_base"] = "http://" + CONFIG["server_host"]	# set this to "" to get relative image urls
CONFIG["admin_contact"] = "dobacco@gmail.com"
CONFIG["email_from"] = "noreply@moe.imouto.org"
CONFIG["image_store"] = :remote_hierarchy
#CONFIG["image_servers"] = ["http://moe.imouto.org", "http://ranka.imouto.org", "http://moe.e-n-m.net"]
CONFIG["image_servers"] = [
        #{ :server => "http://elis.imouto.org", :traffic => 2, },
        { :server => "http://yotsuba.imouto.org", :traffic => 2, :nopreview => false },
#        { :server => "http://elis.imouto.org", :traffic => 3, :nopreview => true },
#        { :server => "http://ranka.imouto.org", :traffic => 1, :previews_only => true } #:nozipfile => true, :nopreview => true }
]
#CONFIG["image_servers"] = ["http://sheryl.imouto.org", "http://ranka.imouto.org", "http://moe.e-n-m.net"]
CONFIG["mirrors"] = [
	{ :user => "moe", :host => "ranka.imouto.org", :data_dir => "/home/moe/moe-live/public/data" },
#        { :user => "moe", :host => "208.43.138.197", :data_dir => "/home/moe/moe-live/public/data" },
#        { :user => "moe", :host => "shana.imouto.org", :data_dir => "/home/moe/moe-live/public/data" },
#        { :user => "moe", :host => "elis.imouto.org", :data_dir => "/home/moe/moe-live/public/data" },
#        { :user => "moe", :host => "188.95.50.2", :data_dir => "/home/moe/moe-live/public/data" },
#        { :user => "moe", :host => "85.12.23.35", :data_dir => "/home/moe/data" },
]
CONFIG["dupe_check_on_upload"] = true
CONFIG["enable_caching"] = true
CONFIG["enable_anonymous_comment_access"] = true
CONFIG["enable_anonymous_safe_post_mode"] = false
CONFIG["use_pretty_image_urls"] = true
CONFIG["download_filename_prefix"] = "moe"
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
CONFIG["local_image_service"] = "moe.imouto.org"
CONFIG["default_blacklists"] = [
  "rating:e loli",
  "rating:e shota",
  "extreme_content",
]
# List of image services available for similar image searching.
CONFIG["image_service_list"] = {
	"danbooru.donmai.us" => "http://iqdb.hanyuu.net/index.xml",
	"moe.imouto.org" => "http://iqdb.hanyuu.net/index.xml",
	"konachan.com" => "http://iqdb.hanyuu.net/index.xml",
	"e-shuushuu.net" => "http://iqdb.hanyuu.net/index.xml",
	"gelbooru.com" => "http://iqdb.hanyuu.net/index.xml",
}
# This sets the minimum and maximum value a single user's vote can affect the post's total score.
CONFIG["vote_sum_max"] = 1
CONFIG["vote_sum_min"] = 0
CONFIG["can_see_ads"] = lambda do |user|

user.is_privileged_or_lower?

end

CONFIG["pool_zips"] = true
CONFIG["comment_threshold"] = 9999
CONFIG["image_samples"] = true
CONFIG["jpeg_enable"] = true

#ActionMailer::Base.delivery_method = :smtp

