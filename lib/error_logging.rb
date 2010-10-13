module ActionController #:nodoc:
  module Rescue
    protected
      alias_method :orig_log_error, :log_error
      def log_error(exception) #:doc:
        case exception
        when
          ActiveRecord::RecordNotFound,
          ActionController::UnknownController,
          ActionController::UnknownAction,
          ActionController::RoutingError
          return
        end

        ActiveSupport::Deprecation.silence do
#          if ActionView::TemplateError === exception
#            logger.fatal(exception.to_s)
#          else
            text = "\n\n"
            text << "#{exception.class} (#{exception.message}) #{self.controller_name}/#{self.action_name}\n"
            text << "Host: #{request.env["REMOTE_ADDR"]}\n"
            text << "U-A: #{request.env["HTTP_USER_AGENT"]}\n"
            
            
            
            text << "Request: http://#{request.env["HTTP_HOST"]}#{request.env["REQUEST_URI"]}\n"
            text << "Parameters: #{request.parameters.inspect}\n" if not request.parameters.empty?
            text << "Cookies: #{request.cookies.inspect}\n" if not request.cookies.empty?
            text << "    "
            text << clean_backtrace(exception).join("\n    ")
            text << "\n\n"
            logger.fatal(text)
#          end
        end

#        orig_log_error exception
      end
  end
end

