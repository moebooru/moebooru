if Rails.env.development?
  Rails.configuration.action_mailer.delivery_method = :file
end
