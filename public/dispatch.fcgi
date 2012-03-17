#!/usr/local/bin/ruby
#
# You may specify the path to the FastCGI crash log (a log of unhandled
# exceptions which forced the FastCGI instance to exit, great for debugging)
# and the number of requests to process before running garbage collection.
#
# By default, the FastCGI crash log is RAILS_ROOT/log/fastcgi.crash.log
# and the GC period is nil (turned off).  A reasonable number of requests
# could range from 10-100 depending on the memory footprint of your app.
#
# Example:
#   # Default log path, normal GC behavior.
#   RailsFCGIHandler.process!
#
#   # Default log path, 50 requests between GC.
#   RailsFCGIHandler.process! nil, 50
#
#   # Custom log path, normal GC behavior.
#   RailsFCGIHandler.process! '/var/log/myapp_fcgi_crash.log'
#
begin
  require File.dirname(__FILE__) + "/../config/environment"
  require 'fcgi_handler'

  RailsFCGIHandler.process!
  #RailsFCGIHandler.process! nil, 20
rescue Exception => e
  # Early exceptions, such as in the environment setup, won't be caught by the
  # regular error handler, because it won't be set up yet.
  File::open("../log/uncaught-exceptions.log", "a") { |f|
    f.write("#{e}\n  #{e.backtrace.join("\n  ")}\n\n")
  }
  raise
end
