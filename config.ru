# This file is used by Rack-based servers to start the application.
if defined? Unicorn
  require 'unicorn/oob_gc'
  use Unicorn::OobGC
  require 'unicorn/worker_killer'
  use Unicorn::WorkerKiller::MaxRequests, 3072, 4096
end

require ::File.expand_path('../config/environment',  __FILE__)
# Passenger hates map. And only it, AFAICT.
if defined? PhusionPassenger
  run Moebooru::Application
else
  map (ENV['RAILS_RELATIVE_URL_ROOT'] || '/') do
    run Moebooru::Application
  end
end
