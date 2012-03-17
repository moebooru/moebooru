#!/usr/bin/env ruby

ENV['NEWRELIC_ENABLE'] = 'false'
require File.dirname(__FILE__) + '/../../config/environment'

JobTask.execute_all
