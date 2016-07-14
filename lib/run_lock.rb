require 'server'

module SidekiqExtendedStrategies
  module RunLock
    module_function
    def self.configure
      yield RunLock.settings
    end

    def self.settings
      @@settings = { run_lock_expire: 60}
    end

    class Server < SidekiqExtendedStrategies::BaseServerMiddleware

      def call_middleware(&blk)
        run_lock? ? acquire_lock_and_run!(&blk) : yield
      end

      REMOVE_ON_MATCH =
        <<-LUA
          if redis.call('GET', KEYS[1]) == ARGV[1] then
            redis.call('DEL', KEYS[1])
          end
        LUA

      def run_lock?
        options['run_lock'.freeze]
      end

      def run_lock_expire
        options['run_lock_expire'.freeze] || RunLock.settings[:run_lock_expire]
      end

      def options
        @options ||= worker.class.respond_to?(:sidekiq_options) ? worker.class.sidekiq_options : {}
      end

      def lock_key
        @lock_key ||= payload_hash(@item)
      end

      def acquire_lock_and_run!(&blk)
        acquired = connection do |con|
          con.set("run:#{lock_key}", @item['jid'.freeze], nx: true, expires: run_lock_expire)
        end
        if acquired
          begin
            yield
          ensure
            unlock
          end
        else
          reschedule_job
        end
      end

      def reschedule_job
        Sidekiq::Client.new(redis_pool).raw_push([@item])
        @item['jid'.freeze]
      end

      protected

      def unlock
        connection do |con|
          con.eval(REMOVE_ON_MATCH, keys: ["run:#{lock_key}"], argv: [@item['jid'.freeze]])
        end
      end
    end
  end
end
