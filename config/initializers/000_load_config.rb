CONFIG["url_base"] ||= "http://" + CONFIG["server_host"]

%w(user_password_salt).each do |key|
  CONFIG[key] = ServerKey[key] if ServerKey[key]
end

require 'base64'
require 'diff/lcs/array'
require 'ipaddr'
require 'open-uri'
require 'socket'
require 'time'
require 'uri'
require 'net/http'
require 'aws/s3' if [:amazon_s3, :local_flat_with_amazon_s3_backup].include?(CONFIG["image_store"])
require 'danbooru_image_resizer/danbooru_image_resizer'
require 'google_chart' if CONFIG["enable_reporting"]
require 'sys/cpu' if CONFIG["load_average_threshold"]
require 'fileutils'

# lib requires
require 'core_extensions'
require 'diff'
require 'download'
require 'dtext'
require 'external_post'
require 'extract_urls'
require 'image_size'
# This one is already loaded by default_config.rb (and it is the only user)
#require 'languages'
require 'mirror'
require 'multipart'
require 'nagato'
require 'post_save'
require 'query_parser'
require 'report'
require 'similar_images'
require 'tokenize'
require 'translate'
require 'versioning'
