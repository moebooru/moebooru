# Be sure to restart your server when you modify this file.

Moebooru::Application.config.session_store :cookie_store, :key => CONFIG["app_name"], :secure => CONFIG["secure"], :domain => CONFIG["server_host"]

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Moebooru::Application.config.session_store :active_record_store
