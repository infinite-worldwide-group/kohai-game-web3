# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins %r{\A(https?://(?:.+\.)?#{Rails.application.secrets[:frontend_url]}(:\d+)?)\z},
            %r{\A(https?://(?:.+\.)?#{Rails.application.secrets[:admin_url]}(:\d+)?)\z},
            %r{\A(https?://(?:.+\.)?#{Rails.application.secrets[:web_url]}(:\d+)?)\z},
            %r{\A(https?://(?:.+\.)?#{Rails.application.secrets[:iwg_url]}(:\d+)?)\z},
            %r{\A(http?://(?:.+\.)?localhost:3002(:\d+)?)\z}

    resource '*',
             headers: :any,
             methods: %i[get post options],
             credentials: true
  end
end