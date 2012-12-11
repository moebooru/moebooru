# If set, email_from is the address the site sends emails as.  If left alone, emails
# are sent from CONFIG["admin_contact"].
CONFIG['email_from'] ||= CONFIG['admin_contact']

# Set default locale.
CONFIG['default_locale'] ||= 'en'

# Set default url_base if not set in local config.
CONFIG['url_base'] ||= 'http://' + CONFIG['server_host']

# Set secure to false by default due to ssl requirement
CONFIG['secure'] ||= false

CONFIG['standalone'] ||= true
CONFIG['bundler_groups'] ||= Rails.groups(:assets => %w(development test))
CONFIG['bundler_groups'] << 'standalone' if CONFIG['standalone']

CONFIG['bgcolor'] ||= 'gray'
