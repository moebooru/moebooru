# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  :key => "session_#{CONFIG["app_name"].parameterize}",
  :secure => CONFIG["secure"],
  :domain => CONFIG["session_domain"],
  :expire_after => 30.days
