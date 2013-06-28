source "https://rubygems.org"

gem "rails", "~> 3.2.0"
gem "jquery-rails"

group :assets do
  gem "sass-rails", "~> 3.2.3"

  gem "uglifier", ">= 1.0.3"
  gem "jquery-ui-rails"
end

gem "pg", :platforms => [:ruby, :mswin, :mingw]
gem "activerecord-jdbcpostgresql-adapter", :platforms => :jruby

gem "diff-lcs"
gem "json"
gem "dalli"
gem "acts_as_versioned_rails3"
gem "geoip"
gem "exception_notification"
gem "will_paginate"
gem "will-paginate-i18n"
gem "sitemap_generator"
gem "daemons", :require => false
gem "newrelic_rpm"
gem "nokogiri"
gem "rails-i18n"
gem "addressable", :require => "addressable/uri"
gem "mini_magick", "= 3.5.0"
gem "cache_digests"
gem "i18n-js"

group :development do
  gem "quiet_assets"
  gem "hooves", :platforms => :mri
end

group :test, :development do
  gem "rspec-rails"
end

group :standalone do
  platform :mri do
    gem "unicorn"
    gem "unicorn-worker-killer"
  end
  gem "puma", :platforms => [:jruby, :rbx]
  gem "thin", :platforms => [:mswin, :mingw]
end

gem "oj", :platforms => :mri
gem "multi_json"
gem "jbuilder"
gem "rack-mini-profiler"
