require_relative 'boot'

# To allow setting environment variable ZP_DATABASE_URL instead of DATABASE_URL.
ENV['DATABASE_URL'] = ENV['MB_DATABASE_URL'] if ENV['MB_DATABASE_URL']

require 'rails/all'

require_relative 'init_config'

Bundler.require(*CONFIG['bundler_groups'])

module Moebooru
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)

    # Also load files in lib/ in addition to app/.
    config.eager_load_paths += ["#{config.root}/lib"]

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    config.i18n.enforce_available_locales = true
    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.available_locales = CONFIG["available_locales"]
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

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = "1.0"

    if CONFIG["memcache_servers"]
      config.cache_store = :dalli_store, CONFIG["memcache_servers"], {
        :namespace => CONFIG["app_name"],
        :pool_size => CONFIG["threads"],
        :value_max_bytes => 2_000_000
      }
    end

    # This one is never reliable because there's no standard controlling this.
    config.action_dispatch.ip_spoofing_check = false

    config.action_controller.asset_host = CONFIG[:file_hosts][:assets] if CONFIG[:file_hosts]
    config.action_mailer.default_url_options = { :host => CONFIG["server_host"] }

    config.middleware.delete ActionDispatch::HostAuthorization
  end
end
