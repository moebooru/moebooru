require_relative "boot"

# To allow setting environment variable MB_DATABASE_URL instead of DATABASE_URL.
ENV["DATABASE_URL"] = ENV["MB_DATABASE_URL"] if ENV["MB_DATABASE_URL"]
ENV["NODE_ENV"] = ENV["RAILS_ENV"]

require "rails/all"

require_relative "init_config"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*CONFIG["bundler_groups"])

module Moebooru
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.available_locales = CONFIG["available_locales"]
    config.i18n.default_locale = CONFIG["default_locale"]

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :sql

    if CONFIG["memcache_servers"]
      config.cache_store = :mem_cache_store, CONFIG["memcache_servers"], {
        namespace: CONFIG["app_name"],
        pool_size: CONFIG["threads"],
        value_max_bytes: 2_000_000
      }
    end

    # This one is never reliable because there's no standard controlling this.
    config.action_dispatch.ip_spoofing_check = false

    scheme = "#{CONFIG['secure'] ? 'https' : 'http'}://"
    config.action_controller.asset_host = "#{scheme}#{CONFIG[:file_hosts][:assets]}" if CONFIG[:file_hosts]
    config.action_mailer.default_url_options = { host: "#{scheme}#{CONFIG["server_host"]}" }

    config.middleware.delete ActionDispatch::HostAuthorization

    config.active_record.belongs_to_required_by_default = false
  end
end
