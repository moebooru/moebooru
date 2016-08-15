# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store, :key => CONFIG["app_name"], :secure => CONFIG["secure"], :domain => CONFIG["server_host"]
