source "https://rubygems.org"

gem "rails", "~> 6.0.0"

gem "webpacker"
gem "coffee-rails"
gem "jquery-rails"
gem "jquery-ui-rails"
gem "uglifier"

gem "sass-rails"

source "https://rails-assets.org" do
  gem "rails-assets-js-cookie"
  gem "rails-assets-mousetrap"
  gem "rails-assets-timeago"
  gem "rails-assets-MutationObserver"
end

gem "non-stupid-digest-assets"

gem "pg", :platforms => [:ruby, :mingw]
gem "activerecord-jdbcpostgresql-adapter", ">= 1.3.0", :platforms => :jruby

gem "diff-lcs"
gem "dalli"
gem "connection_pool"
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
gem "mini_magick"
gem "image_size"
gem "i18n-js", ">= 3.0.0.rc7"
gem "mini_mime"

group :standalone do
  platform :mri do
    gem "unicorn", :require => false
    gem "unicorn-worker-killer", :require => false
  end
  gem "puma", :platforms => [:jruby, :rbx, :mswin], :require => false
end

group :test do
  gem "rails-controller-testing"
end

gem "pry", :group => [:development, :test]

gem "jbuilder", "~> 2.5"

# Must be last.
gem "rack-mini-profiler", :group => :development
