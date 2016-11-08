if Rails.env.production?
  ActionController::Base.log_warning_on_csrf_failure = false
  ActiveSupport::Deprecation.behavior = :stderr
end
