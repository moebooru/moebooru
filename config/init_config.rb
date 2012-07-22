CONFIG = {}
require File.expand_path '../../lib/languages', __FILE__
# The version of this Moebooru.
CONFIG["version"] = '3.2.1-alpha'

# The default name to use for anyone who isn't logged in.
CONFIG["default_guest_name"] = "Anonymous"

# This is a salt used to make dictionary attacks on account passwords harder.
CONFIG["password_salt"] = "choujin-steiner"

# Set to true to allow new account signups.
CONFIG["enable_signups"] = true

# Newly created users start at this level. Set this to 30 if you want everyone
# to start out as a privileged member.
CONFIG["starting_level"] = 20

# What method to use to store images.
# local_flat: Store every image in one directory.
# local_hierarchy: Store every image in a hierarchical directory, based on the post's MD5 hash. On some file systems this may be faster.
# local_flat_with_amazon_s3_backup: Store every image in a flat directory, but also save to an Amazon S3 account for backup.
# amazon_s3: Save files to an Amazon S3 account.
# remote_hierarchy: Some images will be stored on separate image servers using a hierarchical directory.
CONFIG["image_store"] = :local_flat

# Only used when image_store == :remote_hierarchy. An array of image servers (use http://domain.com format).
#
# If nozipfile is set, the mirror won't be used for ZIP mirroring.
CONFIG["image_servers"] = [
#	{ :server => "http://domain.com", :traffic => 0.5 },
#	{ :server => "http://domain.com", :traffic => 0.5, :nozipfile => true },
]

# Set to true to enable downloading whole pools as ZIPs.  This requires mod_zipfile
# for lighttpd.
CONFIG["pool_zips"] = false

# List of servers to mirror image data to.  This is run from the task processor.
# An unpassworded SSH key must be set up to allow direct ssh/scp commands to be
# run on the remote host.  data_dir should point to the equivalent of public/data,
# and should usually be listed in CONFIG["image_servers"] unless this is a backup-
# only host.
CONFIG["mirrors"] = [
	# { :user => "danbooru", :host => "example.com", :data_dir => "/home/danbooru/public/data" },
]

# Enables image samples for large images. NOTE: if you enable this, you must manually create a public/data/sample directory.
CONFIG["image_samples"] = true

# The maximum dimensions and JPEG quality of sample images.  This is applied
# before sample_max/sample_min below.  If sample_width is nil, neither of these
# will be applied and only sample_min/sample_max below will determine the sample
# size.
CONFIG["sample_width"] = nil
CONFIG["sample_height"] = 1000 # Set to nil if you never want to scale an image to fit on the screen vertically
CONFIG["sample_quality"] = 92

# The greater dimension of sample images will be clamped to sample_min, and the smaller
# to sample_min.  2000x1400 will clamp a landscape image to 2000x1400, or a portrait
# image to 1400x2000.
CONFIG["sample_max"] = 1500
CONFIG["sample_min"] = 1200

# The maximum dimensions of inline images for the forums and wiki.
CONFIG["inline_sample_width"] = 800
CONFIG["inline_sample_height"] = 600

# Resample the image only if the image is larger than sample_ratio * sample_dimensions.
# This is ignored for PNGs, so a JPEG sample is always created.
CONFIG["sample_ratio"] = 1.25

# A prefix to prepend to sample files
CONFIG["sample_filename_prefix"] = ""

# Enables creating JPEGs for PNGs.
CONFIG["jpeg_enable"] = false

# Scale JPEGs to fit in these dimensions.
CONFIG["jpeg_width"] = 3500
CONFIG["jpeg_height"] = 3500

# Resample the image only if the image is larger than jpeg_ratio * jpeg_dimensions.  If
# not, PNGs can still have a JPEG generated, but no resampling will be done.
CONFIG["jpeg_ratio"] = 1.25
CONFIG["jpeg_quality"] = 94

# If enabled, URLs will be of the form:
# http://host/image/00112233445566778899aabbccddeeff/12345 tag tag2 tag3.jpg
#
# This allows images to be saved with a useful filename, and hides the MD5 hierarchy (if
# any).  This does not break old links; links to the old URLs are still valid.  This
# requires URL rewriting (not redirection!) in your webserver.  The rules for lighttpd are:
#
# url.rewrite               = (
#	"^/image/([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{28})(/.*)?(\.[a-z]*)" => "/data/$1/$2/$1$2$3$5",
#	"^/sample/([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{28})(/.*)?(\.[a-z]*)" => "/data/sample/$1/$2/$1$2$3$5"
# )
#
CONFIG["use_pretty_image_urls"] = false

# If use_pretty_image_urls is true, sets a prefix to prepend to all filenames.  This
# is only present in the generated URL, and is useful to allow your downloaded files
# to be distinguished from other sites; for example, "moe 12345 tags.jpg" vs.
# "kc 54321 tags.jpg".  If set, this should end with a space.
CONFIG["download_filename_prefix"] = ""

# Files over this size will always generate a sample, even if already within
# the above dimensions.
CONFIG["sample_always_generate_size"] = 512*1024

# These three configs are only relevant if you're using the Amazon S3 image store.
CONFIG["amazon_s3_access_key_id"] = ""
CONFIG["amazon_s3_secret_access_key"] = ""
CONFIG["amazon_s3_bucket_name"] = ""

# This enables various caching mechanisms. You must have memcache (and the memcache-client ruby gem) installed in order for caching to work.
CONFIG["enable_caching"] = false

# Enabling this will cause Danbooru to cache things longer:
# - On post/index, any page after the first 10 will be cached for 3-7 days.
# - post/show is cached
CONFIG["enable_aggressive_caching"] = false

# The server and port where the memcache client can be accessed. Only relevant if you enable caching.
CONFIG["memcache_servers"] = ["localhost:4000"]

# Any post rated safe or questionable that has one of the following tags will automatically be rated explicit.
CONFIG["explicit_tags"] = %w(pussy penis cum anal vibrator dildo masturbation oral_sex sex paizuri penetration guro rape asshole footjob handjob blowjob cunnilingus anal_sex)

# After a post receives this many posts, new comments will no longer bump the post in comment/index.
CONFIG["comment_threshold"] = 40

# Members cannot post more than X posts in a day.
CONFIG["member_post_limit"] = 16

# Members cannot post more than X comments in an hour.
CONFIG["member_comment_limit"] = 2

# This sets the minimum and maximum value a user can record as a vote.
CONFIG["vote_record_min"] = 0
CONFIG["vote_record_max"] = 3

# Descriptions for the various vote levels.
CONFIG["vote_descriptions"] = {
  3 => "Favorite",
  2 => "Great",
  1 => "Good",
  0 => "Neutral",
  -1 => "Bad"
}

# The maximum image size that will be downloaded by a URL.
CONFIG["max_image_size"] = 1024*1024*256

# This allows posts to have parent-child relationships. However, this requires manually updating the post counts stored in table_data by periodically running the script/maintenance script.
CONFIG["enable_parent_posts"] = false

# Show only the first page of post/index to visitors.
CONFIG["show_only_first_page"] = false

CONFIG["enable_reporting"] = false

# Enable some web server specific optimizations. Possible values include: apache, nginx, lighttpd.
CONFIG["web_server"] = "apache"

# Show a link to Trac.
CONFIG["enable_trac"] = true

# The image service name of this host, if any.
CONFIG["local_image_service"] = ""

# List of image services available for similar image searching.
CONFIG["image_service_list"] = {
	"danbooru.donmai.us" => "http://haruhidoujins.yi.org/multi-search.xml",
	"moe.imouto.org" => "http://haruhidoujins.yi.org/multi-search.xml",
	"konachan.com" => "http://haruhidoujins.yi.org/multi-search.xml",
}

# If true, image services receive a URL to the thumbnail for searching, which
# is faster.  If false, the file is sent directly.  Set to false if using image
# services that don't have access to your image URLs.
CONFIG["image_service_local_searches_use_urls"] = true

# If true, run a dupe check on new uploads using the image search
# for local_image_service.
CONFIG["dupe_check_on_upload"] = false

# Defines the various user levels. You should not remove any of the default ones. When Danbooru starts up, the User model will have several methods automatically defined based on what this config contains. For this reason you should only use letters, numbers, and spaces (spaces will be replaced with underscores). Example: is_member?, is_member_or_lower?, is_member_or_higher?
CONFIG["user_levels"] = {
  "Unactivated" => 0,
  "Blocked" => 10,
  "Member" => 20,
  "Privileged" => 30,
  "Contributor" => 33,
  "Janitor" => 35,
  "Mod" => 40,
  "Admin" => 50
}

# Defines the various tag types. You can also define shortcuts.
CONFIG["tag_types"] = {
  "General" => 0,
  "Artist" => 1,
  "Copyright" => 3,
  "Character" => 4,

  "general" => 0,
  "artist" => 1,
  "copyright" => 3,
  "character" => 4,
  "art" => 1,
  "copy" => 3,
  "char" => 4
}

# Tag type IDs to not list in recent tag summaries, such as on the side of post/index:
CONFIG["exclude_from_tag_sidebar"] = [0]

# Determine who can see a post. Note that since this is a block, return won't work. Use break.
CONFIG["can_see_post"] = lambda do |user, post|
  # By default, no posts are hidden.
  true

  # Some examples:
  #
  # Hide post if user isn't privileged and post is not safe:
  # post.rating != "e" || user.is_privileged_or_higher?
  #
  # Hide post if user isn't a mod and post has the loli tag:
  # !post.has_tag?("loli") || user.is_mod_or_higher?
end

# Determines who can see ads. Note that since this is a block, return won't work. Use break.
CONFIG["can_see_ads"] = lambda do |user|
  # By default, only show ads to non-priv users.
  user.is_member_or_lower?

  # Show no ads at all
  # false
end

# Defines the default blacklists for new users.
CONFIG["default_blacklists"] = [
#  "rating:e loli",
#  "rating:e shota",
]

# Enable the artists interface.
CONFIG["enable_artists"] = true

# This is required for Rails 2.0.
CONFIG["secret_token"] = "This should be at least 30 characters long"

# Users cannot search for more than X regular tags at a time.
CONFIG["tag_query_limit"] = 6

# Set this to insert custom CSS or JavaScript files into your app.
CONFIG["custom_html_headers"] = nil

# Set this to true to hand off time consuming tasks (downloading files, resizing images, any sort of heavy calculation) to a separate process.
CONFIG["enable_asynchronous_tasks"] = false

CONFIG["avatar_max_width"] = 125
CONFIG["avatar_max_height"] = 125

# Max number of posts to cache
CONFIG["tag_subscription_post_limit"] = 200

# Max number of fav tags per user
CONFIG["max_tag_subscriptions"] = 5

# Languages that we're aware of.  This is what we show in "Secondary languages", to let users
# select which languages they understand and that shouldn't be translated.
CONFIG["known_languages"] = CONFIG["language_names"].map { |key, lang| key }.sort

# The number of posts a privileged_or_lower can have pending at one time.  Any
# further posts will be rejected.
CONFIG["max_pending_images"] = nil

# If set, posts by privileged_or_lower accounts below this size will be set to
# pending.
CONFIG["min_mpixels"] = nil

# If true, pending posts act like hidden posts: they're hidden from the index unless
# pending:all is used, and posts are bumped to the front of the index when they're
# approved.
CONFIG["hide_pending_posts"] = false

CONFIG['available_locales'] = %w(de en es ja ru cn)
