# If set, email_from is the address the site sends emails as.  If left alone, emails
# are sent from CONFIG["admin_contact"].
CONFIG["email_from"] ||= CONFIG["admin_contact"]

# Set default locale.
CONFIG["default_locale"] ||= "en"

# Set default url_base if not set in local config.
CONFIG["url_base"] ||= "http://#{CONFIG["server_host"] || "localhost"}"

# Set secure to false by default due to ssl requirement
CONFIG["secure"] = false if CONFIG["secure"].nil?

CONFIG["standalone"] = true if CONFIG["standalone"].nil?
CONFIG["bundler_groups"] ||= [:default, Rails.env]
CONFIG["bundler_groups"] << "standalone" if CONFIG["standalone"]

CONFIG["bgcolor"] ||= "gray"

CONFIG["threads"] ||= (ENV["MB_THREADS"] || 1).to_i

CONFIG["piwik_host"] ||= ENV["MB_PIWIK_HOST"]
CONFIG["piwik_site_id"] ||= ENV["MB_PIWIK_ID"]
