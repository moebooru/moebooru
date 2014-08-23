# - append 'need-login' class for buttons
# - add javascript event for links and buttons
# example: :level => :member
module ActionView
  module Helpers
    module MoebooruTagHelper
      # Return true if the starting level is high enough to execute
      # this action.  This is used by User.js.
      # Mirrors the one defined in ApplicationHelper
      def _moebooru_need_signup?(level)
        CONFIG["starting_level"] >= User.get_user_level(level)
      end
      module_function :_moebooru_need_signup?
    end

    module TagHelper
      alias_method :orig_tag_options, :tag_options
      def tag_options(options, escape = true)
        level = options["level"]
        if level and MoebooruTagHelper._moebooru_need_signup?(level)
          options.delete "level"
          options["onclick"] = "if(!User.run_login_onclick(event)) return false; #{options["onclick"] || "return true;"}"
        end
        orig_tag_options options, escape
      end
    end

    module FormTagHelper
      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      alias_method :orig_form_tag, :form_tag
      def form_tag(url_for_options = {}, options = {}, *parameters_for_url, &block)
        if options[:level]
          if MoebooruTagHelper._moebooru_need_signup?(options[:level])
            classes = (options[:class] || "").split(" ")
            classes += ["need-signup"]
            options[:class] = classes.join(" ")
          end
          options.delete :level
        end
        orig_form_tag url_for_options, options, *parameters_for_url, &block
      end
    end

    module JavaScriptHelper
      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      alias_method :orig_link_to_function, :link_to_function
      def link_to_function(name, *args, &block)
        html_options = args.extract_options!
        if html_options[:level]
          if MoebooruTagHelper._moebooru_need_signup?(html_options[:level]) && args[0]
            args[0] = "User.run_login(false, function() { #{args[0]} })"
          end
          html_options.delete :level
        end
        args << html_options
        orig_link_to_function name, *args, &block
      end

      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      alias_method :orig_button_to_function, :button_to_function
      def button_to_function(name, *args, &block)
        html_options = args.extract_options!
        if html_options[:level]
          if MoebooruTagHelper._moebooru_need_signup?(html_options[:level]) && args[0]
            args[0] = "User.run_login(false, function() { #{args[0]} })"
          end
        html_options.delete :level
        end
        args << html_options
        orig_button_to_function name, *args, &block
      end
    end

  end
end
