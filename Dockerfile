# syntax=docker/dockerfile:1
# check=error=true

# Build targets:
#   docker build --target production .    (default, for Kamal deployment)
#   docker build --target development .   (for local development and test)

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Enable jemalloc for reduced memory usage and latency in all environments.
ENV LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    BUNDLE_PATH="/usr/local/bundle"


# ---- Production build stage ----

FROM base AS build

# Set production environment variables
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies
ARG NODE_VERSION=25.9.0
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install application gems
COPY vendor/javascript ./vendor/javascript/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Install node modules
COPY package.json yarn.lock ./
RUN yarn install --immutable

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
ARG APP_HOST=dummy.example.com
RUN SECRET_KEY_BASE_DUMMY=1 APP_HOST=$APP_HOST ./bin/rails assets:precompile


RUN rm -rf node_modules


# ---- Production final stage (default) ----

FROM base AS production

ENV RAILS_ENV="production"

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]


# ---- Development stage ----

FROM base AS development

# RAILS_ENV is not set here — set it at runtime:
#   unset or empty → development (Rails default)
#   RAILS_ENV=test  → test environment

# Install packages needed to build gems and node modules
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies (needed at runtime for yarn watch:css)
ARG NODE_VERSION=25.9.0
ARG YARN_VERSION=1.22.22
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install application gems (all groups — no BUNDLE_WITHOUT, no BUNDLE_DEPLOYMENT)
COPY vendor/javascript ./vendor/javascript/
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install node modules (kept for runtime — yarn watch:css needs them)
COPY package.json yarn.lock ./
RUN yarn install --check-files

# Copy application code
COPY . .

# Precompile bootsnap for faster boot times
RUN bundle exec bootsnap precompile -j 1 app/ lib/ --gemfile

EXPOSE 3000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the Rails server directly (no thruster)
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
