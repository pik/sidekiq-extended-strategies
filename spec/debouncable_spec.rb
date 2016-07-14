require 'spec_helper'
require 'debouncable'

describe SidekiqExtendedStrategies::Debouncable::Server do
  SidekiqExtendedStrategies.enable_debouncable!
  QUEUE = 'sidekiq_extended_test'

  context "#call_middleware" do
    it 'is not called normal jobs' do
      jid = TestWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      expect(subject).to receive(:debouncable?).and_call_original
      expect(subject).not_to receive(:debounce!)
      subject.call(TestWorker.new, item, QUEUE) do
        true
      end
    end

    it 'is called on debouncable? jobs' do
      jid = DebouncableWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      expect(subject).to receive(:debouncable?).and_call_original
      expect(subject).to receive(:debounce!)
      subject.call(DebouncableWorker.new, item, QUEUE) do
        true
      end
    end

  end
  context "#debounce!" do
    it "does not debounce if increment is == 1" do
      jid = DebouncableWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      expect(subject).to receive(:debouncable?).and_call_original
      expect(subject).to receive(:debounce!).and_call_original
      subject.call(DebouncableWorker.new, item, QUEUE) do
        true
      end
      expect(Sidekiq.redis { |c| c.get("debounce_reschedules:#{payload_hash(item)}").to_i || 0 }).to eq(0)
    end

    it "reschedules the job on #debounce! true if increment >= 1" do
      jid = DebouncableWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      Sidekiq.redis { |c| c.incr(payload_hash(item))}
      expect(Sidekiq.redis { |c| c.get(payload_hash(item))}.to_i).to eq(2)
      expect(subject).to receive(:debouncable?).and_call_original
      expect(subject).to receive(:debounce!).and_call_original
      expect(subject).to receive(:reschedule_job).and_call_original
      subject.call(DebouncableWorker.new, item, QUEUE) do
        true
      end
      expect(Sidekiq.redis { |c| c.get("debounce_reschedules:#{payload_hash(item)}").to_i || 0 }).to eq(1)
    end

    it "debounces upto 2x #debounce_standard_period" do
      debounce_standard_period = SidekiqExtendedStrategies::Debouncable.settings[:debounce_standard_period]
      jid = DebouncableWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      # Very large debounce approaches log limit
      Sidekiq.redis { |c| c.incrby(payload_hash(item), 1000)}
      expect(Sidekiq.redis { |c| c.get(payload_hash(item))}.to_i).to eq(1001)
      expect(subject).to receive(:reschedule_job).and_call_original
      did_yield = subject.call(DebouncableWorker.new, item, QUEUE) do
        true
      end
      expect(!!did_yield).to eq(false)
      scheduled = Sidekiq.redis {|c| c.zrange('schedule',0, -1)}.first
      expect(JSON.parse(scheduled)["jid"]).to eq(jid)
      score = Sidekiq.redis {|c| c.zscore('schedule', scheduled)}
    end

    it "debounces with a standard period logarithmically decreasing #debounce_standard_period" do
      debounce_standard_period = SidekiqExtendedStrategies::Debouncable.settings[:debounce_standard_period]
      jid = DebouncableWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      # Debounce starts counting log-decreased debounce based on previous reschedules
      Sidekiq.redis { |c| c.incrby(payload_hash(item), 2)}
      Sidekiq.redis { |c| c.incr("debounce_reschedules:#{payload_hash(item)}") }
      expect(Sidekiq.redis { |c| c.get(payload_hash(item))}.to_i).to eq(3)
      expect(subject).to receive(:reschedule_job).and_call_original
      did_yield = subject.call(DebouncableWorker.new, item, QUEUE) do
        true
      end
      expect(!!did_yield).to eq(false)
      scheduled = Sidekiq.redis {|c| c.zrange('schedule',0, -1)}.first
      expect(JSON.parse(scheduled)["jid"]).to eq(jid)
      score = Sidekiq.redis {|c| c.zscore('schedule', scheduled)}
      expected_score = (item['created_at'] + debounce_standard_period * 0.5).to_i
      # Error correct for some rough rounding
      expect(score.between?(expected_score - 1, expected_score + 1)).to eq(true)
    end

    it "before running clears debounce_reschedules and debounce_increment" do
      jid = DebouncableWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      Sidekiq.redis { |c| c.incrby(payload_hash(item), 2)}
      Sidekiq.redis { |c| c.incrby("debounce_reschedules:#{payload_hash(item)}", 2)}
      expect(subject).not_to receive(:reschedule_job)
      did_yield = subject.call(DebouncableWorker.new, item, QUEUE) do
        true
      end
      expect(did_yield).to eq(true)
      expect(Sidekiq.redis { |c| c.get("debounce_reschedules:#{payload_hash(item)}").to_i || 0 }).to eq(0)
      expect(Sidekiq.redis { |c| c.get(payload_hash(item)).to_i || 0 }).to eq(0)
    end
  end
end
