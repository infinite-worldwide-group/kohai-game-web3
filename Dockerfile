# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.0
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle lock --add-platform x86_64-linux --add-platform aarch64-linux && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times (optional, continue on failure)
RUN bundle exec bootsnap precompile app/ lib/ || echo "Bootsnap precompilation failed, continuing..."

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
# Disable eager loading to avoid loading app code that may require credentials
RUN SECRET_KEY_BASE=dummy_secret_key_base_for_assets_precompile_only \
    DATABASE_URL=nulldb://localhost/db \
    SKIP_SIDEKIQ_CONFIG=true \
    RAILS_FORCE_SSL=false \
    bundle exec rake assets:precompile RAILS_ENV=production EAGER_LOAD=false 2>&1 || \
    (echo "=== ASSET PRECOMPILATION FAILED ===" && \
     echo "Trying with verbose output:" && \
     SECRET_KEY_BASE=dummy_secret_key_base_for_assets_precompile_only \
     DATABASE_URL=nulldb://localhost/db \
     SKIP_SIDEKIQ_CONFIG=true \
     RAILS_FORCE_SSL=false \
     bundle exec rake assets:precompile RAILS_ENV=production EAGER_LOAD=false --trace 2>&1 && \
     exit 1)


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 libvips && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
