# Rails.root/config.ru
require "config/environment"
 
use Rails::Rack::LogTailer
use Rails::Rack::Static
run ActionController::Dispatcher.new
