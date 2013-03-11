source 'https://rubygems.org'

gem 'rails', '~> 3.2.0'
gem 'jquery-rails'

group :assets do
  gem 'sass-rails', '~> 3.2.3'

  gem 'uglifier', '>= 1.0.3'
  gem 'jquery-ui-rails'
end

gem 'pg', :platforms => :ruby
gem 'activerecord-jdbcpostgresql-adapter', :platforms => :jruby

gem 'diff-lcs'
gem 'json'
gem 'dalli'
gem 'acts_as_versioned_rails3'
gem 'geoip'
gem 'exception_notification'
gem 'will_paginate'
gem 'will-paginate-i18n'
gem 'sitemap_generator'
gem 'daemons', :require => false
gem 'newrelic_rpm'
gem 'nokogiri'
gem 'rails-i18n'
gem 'addressable', :require => 'addressable/uri'
gem 'mini_magick'
gem 'cache_digests'
gem 'i18n-js'

group :development do
  gem 'quiet_assets'
  gem 'puma'
  gem 'ruby-prof', :platforms => :mri
end

group :test, :development do
  gem 'rspec-rails'
end

group :standalone do
  gem 'unicorn', :platforms => :mri
  gem 'puma', :platforms => [:jruby, :rbx]
end

gem 'oj', :platforms => :ruby
gem 'multi_json'
