require 'rspec'
require 'pry'
require 'pry-byebug'
require 'sidekiq-extended-strategies'
require 'celluloid/test'
require 'sidekiq'
require 'sidekiq/util'
require 'sidekiq/api'
require 'sidekiq/worker'
require 'rspec-sidekiq'
require 'sidekiq/middleware/chain'
require 'sidekiq/processor'
require 'worker_helper'

Sidekiq::Testing.disable!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.filter_run :focus unless ENV['CI']
  config.run_all_when_everything_filtered = true
  config.disable_monkey_patching!
  config.warnings = false
  config.color = true
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
  config.expose_dsl_globally = true

  config.before(:each) do
    Sidekiq.redis_pool.with do |conn|
      conn.flushall
    end
  end
end

RSpec::Sidekiq.configure do |config|
  # Clears all job queues before each example
  config.clear_all_enqueued_jobs = true

  # Whether to use terminal colours when outputting messages
  config.enable_terminal_colours = true

  # Warn when jobs are not enqueued to Redis but to a job array
  config.warn_when_jobs_not_processed_by_sidekiq = false
end

def payload_hash(item)
  SidekiqExtendedStrategies.payload_hash(item)
end
