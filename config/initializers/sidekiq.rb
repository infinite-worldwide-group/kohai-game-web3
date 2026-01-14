# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-cron'

# Skip Sidekiq configuration during asset precompilation or if Redis is not available
unless ENV['SKIP_SIDEKIQ_CONFIG'] == 'true' || ENV['REDIS_URL'].blank?
  # Sidekiq configuration
  Sidekiq.configure_server do |config|
    config.redis = {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    }

    # Load sidekiq-cron schedule
    schedule_file = 'config/schedule.yml'

    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
      Rails.logger.info 'Sidekiq-cron schedule loaded'
    end
  end

  Sidekiq.configure_client do |config|
    config.redis = {
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    }
  end
end
