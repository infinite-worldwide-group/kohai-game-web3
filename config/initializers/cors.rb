# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

# Skip CORS configuration during asset precompilation
unless ENV['SKIP_SIDEKIQ_CONFIG'] == 'true'
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      # Use environment variables for CORS origins
      frontend_url = ENV["FRONTEND_URL"]
      admin_url = ENV["ADMIN_URL"]
      web_url = ENV["WEB_URL"]
      iwg_url = ENV["IWG_URL"]
      store_url = ENV["STORE_URL"]
      prod_url = ENV["PROD_URL"]
      origins %r{\A(https?://(?:.+\.)?#{frontend_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{admin_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{web_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{iwg_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{store_url}(:\d+)?)\z},
              %r{\A(https?://(?:.+\.)?#{prod_url}(:\d+)?)\z},
              %r{\Ahttps?://localhost(:\d+)?\z}

      resource '*',
               headers: :any,
               methods: %i[get post options],
               credentials: true
    end
  end
end