class TestWorker
  include Sidekiq::Worker
  sidekiq_options queue: :test, retry: 1, backtrace: 10

  sidekiq_retries_exhausted do |msg|
    Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
  end

  def perform(*)
    # NO-OP
  end
end

