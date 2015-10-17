require 'forwardable'

module SidekiqExtendedStrategies
  class BaseServerMiddleware
    extend Forwardable
    def_delegators :SidekiqExtendedStrategies, :connection, :payload_hash
    def_delegators :Sidekiq, :logger
    attr_reader :redis_pool,
                :worker,
                :options,
                :item

    def call(worker, item, _queue, redis_pool = nil, &blk)
      @worker = worker
      @redis_pool = redis_pool
      @item = item
      call_middleware(&blk)
    end

    def options
      @options ||= worker.class.respond_to?(:sidekiq_options) ? worker.class.sidekiq_options : {}
    end

    def lock_key
      @lock_key = payload_hash(item)
    end

    def call_middleware
      raise "Not Implemented"
    end
  end
end
