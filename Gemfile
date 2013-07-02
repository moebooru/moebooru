source "https://rubygems.org"

gem "rails", "~> 4.0.0"
gem "rails-observers"
gem "jquery-rails"

gem "sass-rails"
gem "uglifier"
gem "jquery-ui-rails"

gem "pg", :platforms => [:ruby, :mswin, :mingw]
gem "activerecord-jdbcpostgresql-adapter", :platforms => :jruby

### FIXME: remove this
gem "actionpack-page_caching"
gem "protected_attributes"
### FIXME: remove this

gem "diff-lcs"
gem "json"
gem "dalli"
gem "acts_as_versioned_rails3"
gem "geoip"
gem "exception_notification", ">= 4.0.0.rc1"
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
