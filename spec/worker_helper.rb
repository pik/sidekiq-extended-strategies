require 'sidekiq'
class TestWorker
  include Sidekiq::Worker
  sidekiq_options queue: :sidekiq_extended_test, retry: 1, backtrace: 10
  def perform(*)
    # NO-OP
  end
end

class IncrementalWorker < TestWorker
  sidekiq_options incremental: true
end

class DebouncableWorker < IncrementalWorker
  sidekiq_options debouncable: true
end

class RunLockWorker < IncrementalWorker
  sidekiq_options run_lock: true
end
