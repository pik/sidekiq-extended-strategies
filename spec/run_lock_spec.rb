require 'spec_helper'
require 'run_lock'

describe SidekiqExtendedStrategies::RunLock::Server do
  SidekiqExtendedStrategies.enable_run_lock!
  QUEUE = 'sidekiq_extended_test'
  let(:blk) { {custom_block:1} }

  context "#call_middleware" do
    it 'is not called normal jobs' do
      jid = TestWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      expect(subject).to receive(:run_lock?).and_call_original
      expect(subject).not_to receive(:acquire_lock_and_run!)
      subject.call(TestWorker.new, item, QUEUE) { false }
    end

    it 'is called on run_lock? jobs' do
      jid = RunLockWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      expect(subject).to receive(:run_lock?).and_call_original
      expect(subject).to receive(:acquire_lock_and_run!)
      subject.call(RunLockWorker.new, item, QUEUE) { false }
    end

  end
  context "#acquire_lock_and_run!" do
    it "it yields if run lock is acquired" do
      jid = RunLockWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      expect(subject).to receive(:run_lock?).and_call_original
      expect(subject).to receive(:acquire_lock_and_run!).and_call_original
      ret= subject.call(RunLockWorker.new, item, QUEUE) do
        blk
      end
      expect(ret).to eq(blk)
    end

    it "reschedules the job if run lock cannot be acquired" do
      jid = RunLockWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      Sidekiq.redis { |c| c.set("run:#{payload_hash(item)}", "ALREADY LOCKED")}
      expect(subject).to receive(:run_lock?).and_call_original
      expect(subject).to receive(:acquire_lock_and_run!).and_call_original
      expect(subject).to receive(:reschedule_job).and_call_original
      ret = subject.call(RunLockWorker.new, item, QUEUE) do
        blk
      end
      expect(ret).to eq(jid)
    end

    it "Removes run_lock on job completion" do
      jid = RunLockWorker.perform_async
      item = Sidekiq::Queue.new(QUEUE).find_job(jid).item
      ret = Sidekiq.redis { |c| c.get("run:#{payload_hash(item)}")}
      expect(ret).to eq(nil)
      ret = subject.call(RunLockWorker.new, item, QUEUE) do
        Sidekiq.redis { |c| c.get("run:#{payload_hash(item)}")}
      end
      expect(ret).to eq(jid)
      ret = Sidekiq.redis { |c| c.get("run:#{payload_hash(item)}")}
      expect(ret).to eq(nil)
    end

  end
end
