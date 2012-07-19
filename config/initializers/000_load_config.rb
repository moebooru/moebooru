require 'base64'
require 'diff/lcs/array'
require 'ipaddr'
require 'open-uri'
require 'socket'
require 'time'
require 'uri'
require 'net/http'
require 'aws/s3' if [:amazon_s3, :local_flat_with_amazon_s3_backup].include?(CONFIG["image_store"])
require 'fileutils'

# lib requires
require 'core_extensions'
if RUBY_PLATFORM == 'java'
  require 'danbooru_image_resizer/jruby_resizer'
else
  require 'danbooru_image_resizer/danbooru_image_resizer'
end
require 'diff'
require 'download'
require 'dtext'
require 'external_post'
require 'extract_urls'
# This one is already loaded by default_config.rb (and it is the only user)
#require 'languages'
require 'mirror'
require 'multipart'
require 'nagato'
require 'post_save'
require 'query_parser'
require 'report'
require 'similar_images'
require 'translate'
require 'versioning'
