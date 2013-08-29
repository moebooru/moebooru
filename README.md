[![Code Climate](https://codeclimate.com/github/moebooru/moebooru.png)](https://codeclimate.com/github/moebooru/moebooru)

Moebooru
========

This project is based on original Moebooru which is being used in [yande.re Image Board](http://yande.re). Changes compared to original Moebooru:

* Compatible with Ruby 1.9, JRuby 1.7, and Rubinius 2.0
* Uses Rails 4.0
* Updated gems
* Pool ZIP support for nginx (with `mod_zip`)

As this is still in development, bug reports are welcome.

* [Demo site](http://moe.myconan.net)
* [Source Repository](http://github.com/moebooru/moebooru)

Requirements
------------

As this is ongoing project, there will be more changes on requirement as this project goes. Currently this application requires:

* Ruby 1.9+
* PostgreSQL (tested with 8.4, 9.1, and 9.2)
* Bundler gem
* ImageMagick
* And various other requirement for the gems (check `Gemfile` for the list)

On RHEL5 (and 6), it goes like this:

* gcc
* gcc-c++
* ImageMagick
* jhead
* libxslt-devel
* libyaml-devel
* git
* openssl-devel
* pcre-devel
* postgresql84-contrib
* postgresql84-devel
* postgresql84-server
* readline-devel

Base and EPEL repositories contain all the requirements.

On Ubuntu 10.04.4 LTS

* `apt-get install postgresql-contrib python-software-properties postgresql libpq-dev libxml2-dev libxslt-dev mercurial jhead build-essential libgd2-noxpm-dev`

* [Brightbox repo](http://blog.brightbox.co.uk/posts/next-generation-ruby-packages-for-ubuntu) would work if you're too lazy to compile ruby

* add the ppa and then `apt-get install ruby1.9.3`

Installation
------------

### Database Setup

After initializing PostgreSQL database, create user for moebooru with `createdb` privilege:

    postgres# create user moebooru_user with password 'the_password' createdb;

And then install the required PostgreSQL extensions:

* language plpgsql
* test_parser

using these commands:

    --- postgresql 9.1+
    postgres# \c template1
    postgres# create extension test_parser;

    --- postgresql 8.3, 8.4
    postgres# \c template1
    postgres# create language plpgsql;
    postgres# \q
    --- postgresql 8.3, 8.4, 9.0 - from shell
    # sudo -u postgres psql -d template1 -f "`pg_config --sharedir`/contrib/test_parser.sql"


### Rails Setup

* Run `bundle install`
* Create `config/database.yml` and `config/local_config.rb`
* Initialize database with `bundle exec rake db:reset` (there will be some errors reported which is expected)
* Run `bundle exec rake db:migrate`
* Start the server (`bundle exec unicorn` or `bundle exec puma` if using JRuby/Rubinius)

Plans
-----

* Bug fixes
* Documentation
* And more!
