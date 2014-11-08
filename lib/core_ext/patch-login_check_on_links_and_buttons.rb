# - append 'need-login' class for buttons
# - add javascript event for links and buttons
# example: :level => :member
module ActionView
  module Helpers
    module TagHelper
      def tag_options_with_login_check(options, escape = true)
        level = options["level"]
        if level && ApplicationHelper.need_signup?(level)
          options.delete "level"
          options["onclick"] = "if(!User.run_login_onclick(event)) return false; #{options["onclick"] || "return true;"}"
        end
        tag_options_without_login_check options, escape
      end
      alias_method_chain :tag_options, :login_check
    end

    module FormTagHelper
      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      def form_tag_with_login_check(url_for_options = {}, options = {}, *parameters_for_url, &block)
        if options[:level]
          if ApplicationHelper.need_signup?(options[:level])
            classes = (options[:class] || "").split(" ")
            classes += ["need-signup"]
            options[:class] = classes.join(" ")
          end
          options.delete :level
        end
        form_tag_without_login_check url_for_options, options, *parameters_for_url, &block
      end
      alias_method_chain :form_tag, :login_check
    end

    module JavaScriptHelper
      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      def link_to_function_with_login_check(name, *args, &block)
        html_options = args.extract_options!
        if html_options[:level]
          if ApplicationHelper.need_signup?(html_options[:level]) && args[0]
            args[0] = "User.run_login(false, function() { #{args[0]} })"
          end
          html_options.delete :level
        end
        args << html_options
        link_to_function_without_login_check name, *args, &block
      end
      alias_method_chain :link_to_function, :login_check

      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      def button_to_function_with_login_check(name, *args, &block)
        html_options = args.extract_options!
        if html_options[:level]
          if ApplicationHelper.need_signup?(html_options[:level]) && args[0]
            args[0] = "User.run_login(false, function() { #{args[0]} })"
          end
          html_options.delete :level
        end
        args << html_options
        button_to_function_without_login_check name, *args, &block
      end
      alias_method_chain :button_to_function, :login_check
    end
  end
end
