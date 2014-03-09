source "https://rubygems.org"

gem "rails", "~> 4.0.0"
gem "rails-observers"
gem "jquery-rails"

gem "sass-rails"
gem "uglifier"
gem "jquery-ui-rails"

gem "pg", :platforms => [:ruby, :mswin, :mingw]
gem "activerecord-jdbcpostgresql-adapter", "~> 1.3.0.rc1", :platforms => :jruby

### FIXME: remove this
gem "actionpack-page_caching"
gem "protected_attributes"
### FIXME: remove this

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
# FIXME: 3.6.0 doesn't work on Windows but it contains
#        security fix. Newer version which fixes problems
#        on Windows has yet to be released. Hence master
#        version.
gem "mini_magick"
gem "cache_digests"
gem "i18n-js"

group :development do
  gem "quiet_assets"
  gem "puma"
end

group :standalone do
  platform :mri do
    gem "unicorn"
    gem "unicorn-worker-killer"
    gem "gctools"
  end
  gem "puma", :platforms => [:jruby, :rbx]
  gem "thin", :platforms => [:mswin, :mingw]
end

gem "oj", :platforms => :mri
gem "multi_json"
gem "jbuilder"
gem "rack-mini-profiler"
