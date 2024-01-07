source "https://rubygems.org"

gem "rails", "~> 7.0.1"

gem "sprockets-rails"
# TODO: remove github once 1.2.2 (or later) is released
gem 'jsbundling-rails', github: 'rails/jsbundling-rails', branch: 'main'
gem "terser"

gem "pg"

gem "diff-lcs", require: ['diff-lcs', 'diff/lcs/array']
gem "dalli"
gem "connection_pool"
gem "exception_notification"
gem "will_paginate"
gem "will-paginate-i18n"
gem "sitemap_generator"
gem "daemons", :require => false
gem "newrelic_rpm"
gem "nokogiri"
gem "rails-i18n"
gem "addressable", :require => "addressable/uri"
gem "mini_magick"
gem "i18n-js", "~> 3.0.0"
gem "mini_mime"
gem "puma", require: false

group :test do
  gem "rails-controller-testing"
end

gem "pry", :group => [:development, :test]

gem "jbuilder", "~> 2.5"

# Must be last.
gem "rack-mini-profiler", :group => :development
