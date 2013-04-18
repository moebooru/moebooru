if defined? EscapeUtils
  require 'escape_utils/html/rack' # to patch Rack::Utils
  require 'escape_utils/html/erb' # to patch ERB::Util
  require 'escape_utils/html/cgi' # to patch CGI
  require 'escape_utils/html/haml' # to patch Haml::Helpers
end
