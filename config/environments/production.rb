Moebooru::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = CONFIG['secure']

  # Default logging formatter to keep PID and timestamp
  config.log_formatter = Logger::Formatter.new

  # See everything in the log (default is :info)
  config.log_level = :warn
  config.logger = Logger.new(STDOUT)

  # Recommended by http://help.papertrailapp.com/kb/configuration/unicorn
  config.logger.level = Logger.const_get('WARN')

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  config.assets.precompile += %w( application-error.css )

  config.assets.initialize_on_precompile = false

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = { host: CONFIG['server_host'] }
  config.action_mailer.delivery_method = :sendmail

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  config.middleware.use ExceptionNotification::Rack,
    :ignore_exceptions => %w(ActionController::BadRequest ActionController::UnknownFormat) + ExceptionNotifier.ignored_exceptions,
    :email => {
      :email_prefix => ('[%s] ' % CONFIG['app_name']),
      :sender_address => ('%s <%s>' % ['notifier', CONFIG['email_from']]),
      :exception_recipients => CONFIG['admin_contact']
    }

end
