RAILS_GEM_VERSION = '2.3.14' unless defined? RAILS_GEM_VERSION

require File.join(File.dirname(__FILE__), 'boot')

CONFIG ||= {}
require 'languages'
require "#{Rails.root}/config/default_config"
require "#{Rails.root}/config/local_config"

Rails::Initializer.run do |config|
  # Skip frameworks you're not going to use
  config.frameworks -= [:action_web_service]

  # Add additional load paths for your own custom dirs
  config.autoload_paths += ["#{Rails.root}/app/models/post", "#{Rails.root}/app/models/post/image_store"]

  config.cache_store = :mem_cache_store, CONFIG['memcache_servers'], { :namespace => CONFIG['app_name'], :compress => true }

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug
  #config.log_level = :info

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{Rails.root}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  config.active_record.schema_format = :sql

  #testing new relic
#  config.gem "newrelic_rpm"
end
