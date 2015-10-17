require 'spec_helper'
require 'incremental'

describe SidekiqExtendedStrategies::Incremental do
  SidekiqExtendedStrategies.enable_debouncable!

  describe SidekiqExtendedStrategies::Incremental::Client do
    context '#call' do
      it 'it ignores scheduled jobs' do
        expect_any_instance_of(SidekiqExtendedStrategies::Incremental::Client ).not_to receive(:unique_schedule)
        IncrementalWorker.perform_in(60)
      end

      it 'it ignores non-incremental jobs' do
        TempWorker = IncrementalWorker.dup
        TempWorker.sidekiq_options.delete('incremental')
        expect_any_instance_of(SidekiqExtendedStrategies::Incremental::Client ).not_to receive(:unique_schedule)
        TempWorker.perform_async
        Object.send(:remove_const, :TempWorker)
      end
    end

    context '#queue_lock_expire' do
      it 'obtains expire from #sidekiq_options' do
        TempWorker = IncrementalWorker.dup
        TempWorker.sidekiq_options['incremental_expire'] = 1000
        expect_any_instance_of(SidekiqExtendedStrategies::Incremental::Client).to receive(:queue_lock_expire).and_return(1000)
        TempWorker.perform_async
        Object.send(:remove_const, :TempWorker)
      end

      it 'obtains expire from Incremental#settings' do
        expect_any_instance_of(SidekiqExtendedStrategies::Incremental::Client).to receive(:queue_lock_expire).and_return(60*5)
        IncrementalWorker.perform_async
      end
    end

    context '#unique_schedule' do
      it 'returns true if the job has not been added to the queue before' do
        expect_any_instance_of(SidekiqExtendedStrategies::Incremental::Client).to receive(:unique_schedule).and_return(true)
        IncrementalWorker.perform_async
      end

      it 'returns false if the job has already been added to the queue' do
        IncrementalWorker.perform_async
        expect_any_instance_of(SidekiqExtendedStrategies::Incremental::Client).to receive(:unique_schedule).and_return(false)
        IncrementalWorker.perform_async
      end

      it 'allows a job to be added to the queue' do
        result = Sidekiq.redis { |c| c.llen('queue:sidekiq_extended_test') }
        expect(result).to eq(0)
        IncrementalWorker.perform_async
        result = Sidekiq.redis { |c| c.llen('queue:sidekiq_extended_test') }
        expect(result).to eq(1)
      end

      it 'does not add duplicate jobs to the queue' do
        result = Sidekiq.redis { |c| c.llen('queue:sidekiq_extended_test') }
        expect(result).to eq(0)
        IncrementalWorker.perform_async
        IncrementalWorker.perform_async
        result = Sidekiq.redis { |c| c.llen('queue:sidekiq_extended_test') }
        expect(result).to eq(1)
      end

      it 'increments the lock for each job' do
        hash = SidekiqExtendedStrategies.get_payload('IncrementalWorker', 'sidekiq_extended_test', [])
        result = Sidekiq.redis { |c| c.get("#{hash}") }
        expect(result).to eq(nil)
        IncrementalWorker.perform_async
        result = Sidekiq.redis { |c| c.get("#{hash}") }
        expect(result).to eq("1")
        IncrementalWorker.perform_async
        result = Sidekiq.redis { |c| c.get("#{hash}") }
        expect(result).to eq("2")
      end
    end
  end
end
