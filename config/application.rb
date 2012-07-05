# Put this in config/application.rb
require File.expand_path('../boot', __FILE__)
CONFIG = {}
require File.expand_path('../init_config', __FILE__)
require File.expand_path('../local_config', __FILE__)
require File.expand_path('../default_config', __FILE__)

require 'rails/all'

Bundler.require(:default, Rails.env) if defined?(Bundler)

module Moebooru
  class Application < Rails::Application
    config.encoding = 'utf-8'

    # Add additional load paths for your own custom dirs
    config.autoload_paths += [config.root.join('lib')]

    # Force all environments to use the same logger level
    # (by default production uses :info, the others :debug
    #config.log_level = :info

    if CONFIG['enable_caching']
      config.cache_store = :dalli_store, CONFIG['memcache_servers'], { :namespace => CONFIG['app_name'] }
    else
      config.cache_store = :file_store, Rails.root.join('tmp/cache')
    end

    # Activate observers that should always be running
    config.active_record.observers = :user_record_observer

    # Make Active Record use UTC-base instead of local time
    # config.active_record.default_timezone = :utc

    # Use Active Record's schema dumper instead of SQL when creating the test database
    # (enables use of different database adapters for development and test environments)
    config.active_record.schema_format = :sql

    config.action_mailer.smtp_settings = { :openssl_verify_mode => 'none', :domain => CONFIG['server_host'] }
    config.filter_parameters += [:password]

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = CONFIG['default_locale']
  end
end
