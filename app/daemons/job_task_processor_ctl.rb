#!/usr/bin/env ruby

ENV['NEWRELIC_ENABLE'] = 'false'
require 'rubygems'
require 'daemons'

Daemons.run(File.expand_path("../job_task_processor.rb", __FILE__), :log_output => true, :dir => "../../log")
