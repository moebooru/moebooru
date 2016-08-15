# - append 'need-login' class for buttons
# - add javascript event for links and buttons
# example: :level => :member
module ActionView
  module Helpers
    module TagHelperWithLoginCheck
      def tag_options(options, escape = true)
        level = options.delete "level"
        if level && ApplicationHelper.need_signup?(level)
          options["onclick"] = "if(!User.run_login_onclick(event)) return false; #{options["onclick"] || "return true;"}"
        end

        super
      end
    end

    module TagHelper
      prepend TagHelperWithLoginCheck
    end

    module FormTagHelperWithLoginCheck
      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      def form_tag(url_for_options = {}, options = {}, *parameters_for_url, &block)
        level = options.delete :level
        if level && ApplicationHelper.need_signup?(level)
          options[:class] = "#{options[:class]} need-signup"
        end

        super
      end
    end

    module FormTagHelper
      prepend FormTagHelperWithLoginCheck
    end

    module JavaScriptHelper
      # Backported
      def link_to_function_without_login_check(name, function, html_options = {})
        # message = "link_to_function is deprecated and will be removed from Rails 4.1. We recommend using Unobtrusive JavaScript instead. " +
        #   "See http://guides.rubyonrails.org/working_with_javascript_in_rails.html#unobtrusive-javascript"
        # ActiveSupport::Deprecation.warn message

        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;"
        href = html_options[:href] || "#"

        content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
      end

      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      def link_to_function(name, *args, &block)
        html_options = args.extract_options!
        level = html_options.delete :level
        if level && ApplicationHelper.need_signup?(level) && args[0]
          args[0] = "User.run_login(false, function() { #{args[0]} })"
        end
        args << html_options

        link_to_function_without_login_check name, *args, &block
      end

      # Backported
      def button_to_function_without_login_check(name, function = nil, html_options = {})
        # message = "button_to_function is deprecated and will be removed from Rails 4.1. We recommend using Unobtrusive JavaScript instead. " +
        #   "See http://guides.rubyonrails.org/working_with_javascript_in_rails.html#unobtrusive-javascript"
        # ActiveSupport::Deprecation.warn message

        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function};"

        tag(:input, html_options.merge(:type => "button", :value => name, :onclick => onclick))
      end

      # Add the need-signup class if signing up would allow a logged-out user to
      # execute this action.  User.js uses this to determine whether it should ask
      # the user to create an account.
      def button_to_function(name, *args, &block)
        html_options = args.extract_options!
        level = html_options.delete :level
        if level && ApplicationHelper.need_signup?(level) && args[0]
          args[0] = "User.run_login(false, function() { #{args[0]} })"
        end
        args << html_options

        button_to_function_without_login_check name, *args, &block
      end
    end
  end
end
