# frozen_string_literal: true

# Ensure secret_key_base is loaded from environment variable in production
Rails.application.config.secret_key_base = ENV['SECRET_KEY_BASE'] if Rails.env.production?
