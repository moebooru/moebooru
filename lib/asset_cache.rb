require "action_view/helpers/tag_helper.rb"
require "action_view/helpers/asset_tag_helper.rb"

# Fix a bug in expand_javascript_sources: if the cache file exists, but the server
# is started in development, the old cache will be included among all of the individual
# source files.
module ActionView
  module Helpers
    module AssetTagHelper
      private
      class AssetCollection
        def orig_all_asset_files
          path = [public_directory, ('**' if @recursive), "*.#{extension}"].compact
          Dir[File.join(*path)].collect { |file|
            file[-(file.size - public_directory.size - 1)..-1].sub(/\.\w+$/, '')
          }.sort
        end
        def all_asset_files
          x = orig_all_asset_files
          x.delete("application")
          x
        end
      end
    end
  end
end

# Fix another bug: if the javascript sources are changed, the cache is never
# regenerated.  Call on init.
module AssetCache
  # This is dumb.  How do I call this function without wrapping it in a class?
  class RegenerateJavascriptCache
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
  end

  def clear_js_cache
    # Don't do anything if caching is disabled; we won't use the file anyway, and
    # if we're in a rake script, we'll delete the file and then not regenerate it.
    return if not ActionController::Base.perform_caching

    # Overwrite the file atomically, so nothing breaks if a user requests the file
    # before we finish writing it.
    path = (defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/public" : "public")
    # HACK: Many processes will do this simultaneously, and they'll pick up
    # the temporary application-new-12345 file being created by other processes
    # as a regular Javascript file and try to include it in their own, causing
    # weird race conditions.  Write the file in the parent directory.
    cache_temp = "../../tmp/application-new-#{$PROCESS_ID}" 
    temp = "#{path}/javascripts/#{cache_temp}.js" 
    file = "#{path}/javascripts/application.js"
    File.unlink(temp) if File.exist?(temp)
    c = RegenerateJavascriptCache.new
    c.javascript_include_tag(:all, :cache => cache_temp) 

    FileUtils.mv(temp, file)
  end

  module_function :clear_js_cache
end

