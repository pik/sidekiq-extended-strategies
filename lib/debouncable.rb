require 'server'

module SidekiqExtendedStrategies
  module Debouncable
    module_function
    def self.configure
      yield Debouncable.settings
    end

    def self.settings
      @@settings = { debounce_standard_period: 15 }
    end

    class Server < SidekiqExtendedStrategies::BaseServerMiddleware

      def call_middleware(&blk)
        yield unless debouncable? && debounce!
      end

      def debouncable?
        options['debouncable'.freeze]
      end

      def debounce_standard_period
        options['debounce_standard_period'.freeze] || Debouncable.settings[:debounce_standard_period]
      end

      def reschedule_job(delay)
        @item.delete('enqueued_at'.freeze)
        @item["at".freeze] = Time.now.to_i + delay
        Sidekiq::Client.new(redis_pool).raw_push([@item])
        @item['jid'.freeze]
      end

      def debounce_reschedules
        # If debounce_reschedules is nil than it has never been rescheduled due to debounce yet
        @debounce_reschedules ||= connection { |con| con.get("debounce_reschedules:#{lock_key}").to_i || 0 }
      end

      def debounce_increment
        @debounce_increment ||= connection do |con|
          # Subtract 1 to negate the increment from itself
          con.get(lock_key).to_i - 1
        end
      end

      def get_debounce_time
        debounce_range = debounce_reschedules ... debounce_increment
        debounce_time = debounce_range.reduce(0) { |n,i| n + debounce_standard_period.to_f/(2**i) }.to_i
      end

      def debounce!
        if (debounce_time = get_debounce_time) > 0
          connection {|con| con.incrby("debounce_reschedules:#{lock_key}", (debounce_increment - debounce_reschedules)) }
          reschedule_job(debounce_time)
        else
          connection do |conn|
            conn.multi do
              conn.set("#{lock_key}", 0)
              conn.set("debounce_reschedules:#{lock_key}", 0)
            end
          end
          false
        end
      end

    end
  end
end
