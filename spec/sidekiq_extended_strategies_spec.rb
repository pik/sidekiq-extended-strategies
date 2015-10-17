require 'spec_helper'

describe SidekiqExtendedStrategies do
  context '#enable_debouncable!' do
    it 'adds debouncalbe middleware to server chain' do
      SidekiqExtendedStrategies.enable_debouncable!
      expect(Sidekiq.client_middleware.first.instance_variable_get('@klass')).to eq(SidekiqExtendedStrategies::Incremental::Client)
    end
    it 'adds incremental middleware to client chain' do
      SidekiqExtendedStrategies.enable_debouncable!
      debouncable_entry = Sidekiq.server_middleware.entries.any? {|entry| entry.instance_variable_get('@klass') == SidekiqExtendedStrategies::Debouncable::Server}
      expect(debouncable_entry).to eq(true)
    end
  end

  context '#enable_run_lock!' do
    it 'adds run_lock middleware to server chain' do
      SidekiqExtendedStrategies.enable_run_lock!
      expect(Sidekiq.client_middleware.first.instance_variable_get('@klass')).to eq(SidekiqExtendedStrategies::Incremental::Client)
    end
    it 'adds incremental middleware to client chain' do
      SidekiqExtendedStrategies.enable_run_lock!
      run_lock_entry = Sidekiq.server_middleware.entries.any? {|entry| entry.instance_variable_get('@klass') == SidekiqExtendedStrategies::RunLock::Server}
      expect(run_lock_entry).to eq(true)
    end
  end

  it 'does not add duplicate middlewares' do
    SidekiqExtendedStrategies.enable_run_lock!
    SidekiqExtendedStrategies.enable_debouncable!
    expect(Sidekiq.client_middleware.entries.size).to eq(1)
    expect(Sidekiq.client_middleware.first.instance_variable_get('@klass')).to eq(SidekiqExtendedStrategies::Incremental::Client)
  end
end
