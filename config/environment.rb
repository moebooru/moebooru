RAILS_GEM_VERSION = "2.2.2"

require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Skip frameworks you're not going to use
  config.frameworks -= [:action_web_service]

  # Add additional load paths for your own custom dirs
  config.load_paths += ["#{RAILS_ROOT}/app/models/post", "#{RAILS_ROOT}/app/models/post/image_store"]

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug
  config.log_level = :info

  # Enable page/fragment caching by setting a file-based store
  # (remember to create the caching directory and make it readable to the application)
  # config.action_controller.fragment_cache_store = :file_store, "#{RAILS_ROOT}/cache"

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc

  # Use Active Record's schema dumper instead of SQL when creating the test database
  # (enables use of different database adapters for development and test environments)
  config.active_record.schema_format = :sql
end

if RAILS_GEM_VERSION == '2.2.2'
  module ActionMailer
    class Base
      def perform_delivery_smtp(mail)
        destinations = mail.destinations
        mail.ready_to_send
        sender = mail['return-path'] || mail.from

        smtp = Net::SMTP.new(smtp_settings[:address], smtp_settings[:port])
        smtp.enable_starttls_auto if smtp_settings[:enable_starttls_auto] && smtp.respond_to?(:enable_starttls_auto)
        smtp.start(smtp_settings[:domain], smtp_settings[:user_name], smtp_settings[:password],
              smtp_settings[:authentication]) do |smtp|
                smtp.sendmail(mail.encoded, sender, destinations)
              end
       end
    end
  end
else
  raise "Remove ActionMailer TLS patch"
end
