#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

Daemons.run(File.dirname(__FILE__) + "/job_task_processor.rb", :log_output => true, :dir => "../../log")
