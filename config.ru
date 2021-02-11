# This file is used by Rack-based servers to start the application.
if defined? Unicorn
  require "unicorn/worker_killer"
  use Unicorn::WorkerKiller::MaxRequests, 4096, 8192
  use Unicorn::WorkerKiller::Oom, (384*(1024**2)), (512*(1024**2))
end

require_relative "config/environment"
# Passenger hates map. And only it, AFAICT.
if defined? PhusionPassenger
  run Rails.application
  Rails.application.load_server
else
  ENV["RAILS_RELATIVE_URL_ROOT"] ||= "/"

  map ENV["RAILS_RELATIVE_URL_ROOT"] do
    run Rails.application
    Rails.application.load_server
  end
end
