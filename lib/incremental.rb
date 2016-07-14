module SidekiqExtendedStrategies
  module Incremental
    module_function
    def self.configure
      yield Incremental.settings
    end

    def self.settings
      @@settings = { incremental_expire: 60*5, incremental_log_duplicate: false }
    end

    class Client
      extend Forwardable
      def_delegators :SidekiqExtendedStrategies, :connection, :payload_hash
      def_delegators :Sidekiq, :logger
      attr_reader :item, :worker_class, :queue

      def call(worker_class, item, queue, redis_pool = nil)
        @worker_class = (worker_class).is_a?(String) ? worker_class.constantize : worker_class
        @item = item
        return yield if item['at'.freeze] || !incremental?

        @queue = queue
        item['unique_hash'.freeze] = payload_hash(item)
        if unique_schedule
          yield
        else
          logger.info "payload is not unique #{item}" if log_duplicate?
          return
        end
      end

      private

      def incremental?
        worker_class.sidekiq_options['incremental'.freeze]
      end

      def log_duplicate?
        worker_class.sidekiq_options['incremental_log_duplicate'.freeze] || Incremental.settings[:incremental_log_duplicate]
      end

      def unique_schedule
        connection do |conn|
          ret = conn.incr(item['unique_hash'.freeze])
          conn.expire(item['unique_hash'.freeze], queue_lock_expire)
          ret == 1
        end
      end

      def queue_lock_expire
        worker_class.get_sidekiq_options['incremental_expire'.freeze] || Incremental.settings[:incremental_expire]
      end
    end
  end
end



