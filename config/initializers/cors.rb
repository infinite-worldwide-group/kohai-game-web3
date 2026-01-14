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
      frontend_url = Rails.application.secrets[:frontend_url]
      admin_url = Rails.application.secrets[:admin_url]
      web_url = Rails.application.secrets[:web_url]
      iwg_url = Rails.application.secrets[:iwg_url]
      store_url = Rails.application.secrets[:store_url] 
      prod_url = Rails.application.secrets[:prod_url] 
      origins %r{\A(https?://(?:.+\.)?#{frontend_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{admin_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{web_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{iwg_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{store_url}(:\d+)?)\z}

      resource '*',
               headers: :any,
               methods: %i[get post options],
               credentials: true
    end
  end
end