# require 'spec_helper'
# class SomeWorker
#   include Sidekiq::Worker
#   def perform(*)
#     puts "#{self.class}: Working within batch #{bid}"
#     batch.jobs do
#       AnotherWorker.perform_async
#     end
#   end
# end
# class AnotherWorker
#   include Sidekiq::Worker
#   def perform(*)
#     puts "#{self.class}: Working within batch #{bid}"
#   end
# end
=begin
RSpec.describe "Batch Tests" do
  before(:each) do
    Sidekiq.redis.flushall
  end

  batch = Sidekiq::Batch.new
  batch.description = "Batch description (this is optional)"
  batch.jobs do
    4.times { |i| SomeWorker.perform_async(i) }
  end
end
=end
=begin

  it "foo" do
    batch = Sidekiq::Batch.new
    batch.description = "Batch description (this is optional)"
    batch.jobs do
      rows.each { |row| RowWorker.perform_async(row) }
    end
puts "Just started Batch #{batch.bid}"
  end
end
=end
