[![Code Climate](https://codeclimate.com/github/moebooru/moebooru.png)](https://codeclimate.com/github/moebooru/moebooru)

Moebooru
========

An image board.

* [Source Repository](https://github.com/moebooru/moebooru)

Requirements
------------

As this is ongoing project, there will be more changes on requirement as this project goes. Currently this application is developed using:

* Ruby (3.1 or later)
* PostgreSQL (14 or later)
* Bundler gem
* node.js (16.0 or later)
* ImageMagick
* And various other requirement for the gems (check `Gemfile` for the list)

On RHEL, it goes like this (untested):

* ImageMagick
* gcc
* gcc-c++
* git
* jhead
* libxslt-devel
* libyaml-devel
* nodejs
* openssl-devel
* pcre-devel
* postgresql14-devel
* postgresql14-server

Base, EPEL, dnf module, and postgresql official repositories contain all the requirements.

Installation
------------

### Database Setup

After initializing PostgreSQL database, create user for moebooru with `createdb` privilege:

    postgres# create user moebooru_user with password 'the_password' createdb;


### Rails Setup (development)

* Run `bundle install`
* Create `config/database.yml` and `config/local_config.rb`
* Initialize database with `bundle exec rake db:reset`
* Run `bundle exec rake db:migrate`
* Start the server (`bundle exec rails server`)
* Start asset builder server (`npm run build -- --watch`)

### Rails Docker Setup

* [Install Docker and dependencies](https://docs.docker.com/engine/install/)
* Creates three PSQL containers for each environment
* Builds and deploys moebooru container

| Environment Vars           | Default                            | Description                                                                  |
|----------------------------|------------------------------------|------------------------------------------------------------------------------|
| **LOCAL_CONFIG_PATH**        | `config/local_config.rb.example`   | Sets the local path config                                                   |
| **DATABASE_CONFIG_PATH**     | `config/database.yml.docker.example` | Sets the database path config                                                |
| **RAILS_ENV**                | `development`                      | Sets the environment to deploy moebooru                                      |
| **COMMAND_PARAMS**           | `echo ''`                          | Runs command on container creation                                           |
| **ARCHITECTURE**             | `x86_64`                           | Sets architecture to use. Please refer to [Docker Ruby Tags](https://hub.docker.com/_/ruby/tags) |
| **APP_LISTEN_IP**            | `0.0.0.0`                          | Sets moebooru listen IP                                                      |
| **HOST_PORT**                | `8080`                             | Sets port on host to bind to moebooru port                                   |
| **DB_TEST_VOL_PATH**         | `null`                             | Sets Postgresql DB Volume Path for Test environment                          |
| **DB_PRODUCTION_VOL_PATH**   | `null`                             | Sets Postgresql DB Volume Path for Prod environment                          |
| **DB_DEVELOPMENT_VOL_PATH**  | `null`                             | Sets Postgresql DB Volume Path for Dev environment                           |
| **DB_USERNAME**              | `postgres`                         | Sets Postgresql DB username                                                  |
| **DB_PASSWORD**              | `imouto`                           | Sets Postgresql DB password                                                  |

Information on utilizing these variables can be found here in each separate environment:
* [moebooru-app.dev.env.example](.docker/moebooru-app.dev.env.example)
* [moebooru-app.test.env.example](.docker/moebooru-app.test.env.example)
* [moebooru-app.prod.env.example](.docker/moebooru-app.prod.env.example)
* [moebooru-db.env.example](.docker/moebooru-db.env.example)

Sample Deployment:
```
# Build the image
docker compose --env-file .docker/moebooru-app.dev.env.example --env-file .docker/moebooru-db.env.example -f docker-compose.yml -f .docker/docker-compose.dev.yml build

# Start the container
docker compose --env-file .docker/moebooru-app.dev.env.example --env-file .docker/moebooru-db.env.example -f docker-compose.yml -f .docker/docker-compose.dev.yml up -d

# Destroy the container
docker compose --env-file .docker/moebooru-app.dev.env.example --env-file .docker/moebooru-db.env.example -f docker-compose.yml -f .docker/docker-compose.dev.yml down
```

Configuration
-------------

See `config/local_config.rb.example`. Additionally, as I move to ENV-based configuration, here's the list of currently supported ENV variables:

- `MB_DATABASE_URL`: sets database connection configuration. Syntax: `postgres://<user>(:<pass>)@<host>(:<port>)/<dbname>`.
- `MB_MEMCACHE_SERVERS`: addresses of memcache servers. Separated by comma.
- `MB_PIWIK_HOST`: sets the host this application will attempt to contact a Piwik installation at. Defaults to false to not use Piwik if unset.
- `MB_PIWIK_ID`: sets the Site ID this application will send analytics data for.
- `MB_THREADS`: sets number of threads this application is running. Currently used to determine number of connection pool for `memcached`. Defaults to 1 if unset.

Plans
-----

* Bug fixes
* Documentation
* And more!
