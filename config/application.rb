require File.expand_path("../boot", __FILE__)

# Pick the frameworks you want:
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "active_resource/railtie"
require "sprockets/railtie"
require "rails/test_unit/railtie"

require File.expand_path("../init_config", __FILE__)
suppress(LoadError) { require File.expand_path("../local_config", __FILE__) }
require File.expand_path("../default_config", __FILE__)

Bundler.require(*CONFIG["bundler_groups"])

module Moebooru
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Also load files in lib/ in addition to app/.
    config.eager_load_paths += ["#{config.root}/lib"]

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer
    config.active_record.observers = :user_record_observer, :comment_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    config.i18n.enforce_available_locales = true
    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = CONFIG["default_locale"]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = false

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = "1.0"

    if CONFIG["enable_caching"]
      config.cache_store = :dalli_store, CONFIG["memcache_servers"], { :namespace => CONFIG["app_name"], :pool_size => CONFIG["threads"] }
    else
      config.cache_store = :null_store
    end

    # This one is never reliable because there's no standard controlling this.
    config.action_dispatch.ip_spoofing_check = false

    # Save cache in different location to avoid collision.
    config.action_controller.page_cache_directory = config.root.join("public", "cache")

    config.action_controller.asset_host = CONFIG[:file_hosts][:assets] if CONFIG[:file_hosts]
    config.action_mailer.default_url_options = { :host => CONFIG["server_host"] }
  end
end
