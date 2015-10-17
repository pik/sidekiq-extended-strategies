require 'sidekiq'

module SidekiqExtendedStrategies
  module_function
  PREFIX = 'SES'
  def get_payload(klass, queue, *args)
    md5_arguments = { class: klass, args: args , queue: queue}
    "#{PREFIX}:" \
      "#{Digest::MD5.hexdigest(Sidekiq.dump_json(md5_arguments))}"
  end

  def payload_hash(item)
    get_payload(item['class'], item['queue'], item['args'])
  end

  def enable_debouncable!
    configure_client_middleware do |chain|
      require 'incremental'
      chain.add SidekiqExtendedStrategies::Incremental::Client
    end
    configure_server_middleware do |chain|
      require 'debouncable'
      chain.add SidekiqExtendedStrategies::Debouncable::Server
    end
  end

  def enable_run_lock!
    configure_client_middleware do |chain|
      require 'incremental'
      chain.add SidekiqExtendedStrategies::Incremental::Client
    end
    configure_server_middleware do |chain|
      require 'run_lock'
      chain.add SidekiqExtendedStrategies::RunLock::Server
    end
  end

  def configure_server_middleware
    Sidekiq.server_middleware do |chain|
      yield chain
    end
  end

  def configure_client_middleware
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        yield chain
      end
    end
  end

  def connection(redis_pool = nil, &block)
    redis_pool ? redis_pool.with(&block) : Sidekiq.redis(&block)
  end
end
