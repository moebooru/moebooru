FROM ruby:3.1-alpine

# Additional environment variables that can be set
# ENV MB_DATABASE_URL $MB_DATABASE_URL
# ENV MB_MEMCACHE_SERVERS $MB_MEMCACHE_SERVERS
# ENV MB_PIWIK_HOST $MB_PIWIK_HOST
# ENV MB_PIWIK_ID $MB_PIWIK_ID
# ENV MB_THREADS $MB_THREADS

ENV RAILS_ENV $RAILS_ENV

ARG DATABASE_CONFIG_PATH=${DATABASE_CONFIG_PATH:-config/database.yml.docker.example}
ARG LOCAL_CONFIG_PATH=${LOCAL_CONFIG_PATH:-config/local_config.rb.example}

RUN apk add --no-cache curl build-base libpq-dev npm imagemagick nodejs tzdata postgresql-client

RUN bundle config --global frozen 1

WORKDIR /moebooru

COPY . .
COPY ${LOCAL_CONFIG_PATH} ./config/local_config.rb

COPY ${DATABASE_CONFIG_PATH} ./config/database.yml

RUN bundle install
RUN npm install

ENTRYPOINT ["/bin/sh", "-c"]
