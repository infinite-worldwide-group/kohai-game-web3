# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

# Skip CORS configuration during asset precompilation
unless ENV['SKIP_SIDEKIQ_CONFIG'] == 'true'
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      # Use default values if secrets are not available
      frontend_url = Rails.application.secrets[:frontend_url] || 'example.com'
      admin_url = Rails.application.secrets[:admin_url] || 'example.com'
      web_url = Rails.application.secrets[:web_url] || 'example.com'
      iwg_url = Rails.application.secrets[:iwg_url] || 'example.com'

      origins %r{\A(https?://(?:.+\.)?#{frontend_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{admin_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{web_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{iwg_url}(:\d+)?)\z},
              %r{\A(http?://(?:.+\.)?192.168.0.131:3002(:\d+)?)\z},
              %r{\A(http?://(?:.+\.)?localhost:3002(:\d+)?)\z},
              %r{\A(http?://(?:.+\.)?localhost:3003(:\d+)?)\z}

      resource '*',
               headers: :any,
               methods: %i[get post options],
               credentials: true
    end
  end
end