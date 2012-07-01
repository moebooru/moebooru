# This file is used by Rack-based servers to start the application.
if defined? Unicorn
  require 'unicorn/oob_gc'
  use Unicorn::OobGC
end

require ::File.expand_path('../config/environment',  __FILE__)
run Moebooru::Application
