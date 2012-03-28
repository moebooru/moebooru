#!/usr/bin/env ruby

ENV['NEWRELIC_ENABLE'] = 'false'
require File.expand_path('../../../config/environment', __FILE__)

JobTask.execute_all
