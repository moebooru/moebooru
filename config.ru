# This file is used by Rack-based servers to start the application.
if defined? Unicorn
  require 'unicorn/oob_gc'
  use Unicorn::OobGC
end

require ::File.expand_path('../config/environment',  __FILE__)
map (ENV['RAILS_RELATIVE_URL_ROOT'] || '/') do
  run Moebooru::Application
end
