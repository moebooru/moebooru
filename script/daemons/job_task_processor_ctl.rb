#!/usr/bin/env ruby

require "daemons"

ENV["NEWRELIC_ENABLE"] = "false"
job_script = File.expand_path("../job_task_processor.rb", __FILE__)
job_options = {
  :dir_mode => :normal,
  :dir => File.expand_path("../../../log", __FILE__),
  :log_output => true,
  :multiple => false
}
Daemons.run job_script, job_options
