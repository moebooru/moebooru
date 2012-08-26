#!/usr/bin/env ruby

require 'daemons'

ENV['NEWRELIC_ENABLE'] = 'false'
Daemons.run(File.expand_path('../job_task_processor.rb', __FILE__), :log_output => true, :dir => File.expand_path('../../../log', __FILE__))
