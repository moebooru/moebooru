source "https://rubygems.org"

gem "rails", "~> 7.0.1"

gem "sprockets-rails"
gem "jsbundling-rails"
gem "terser"

gem "non-stupid-digest-assets"

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

group :standalone do
  gem "unicorn", :require => false
  gem "unicorn-worker-killer", :require => false
  gem "puma"
end

group :test do
  gem "rails-controller-testing"
end

gem "pry", :group => [:development, :test]

gem "jbuilder", "~> 2.5"

# Must be last.
gem "rack-mini-profiler", :group => :development
