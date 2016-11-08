if Rails.env.production?
  Rails.application.config.action_controller.log_warning_on_csrf_failure = false
end
