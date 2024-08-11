# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'active_job/railtie'
require 'async/job/adapter/active_job'

class AsyncJobTestJob < ActiveJob::Base
	self.queue_adapter = :async_job
	
	def perform(*arguments, **options)
		Console.debug(self, "Performing job...", arguments: arguments, options: options)
	end
end

describe Async::Job::Adapter::ActiveJob::Railtie do
	it "can create an instance" do
		expect(AsyncJobTestJob.queue_adapter).to be_a(ActiveJob::QueueAdapters::AsyncJobAdapter)
	end
	
	it "defaults to inline backend" do
		dispatcher = subject.dispatcher
		
		queue = dispatcher["default"]
		expect(queue.client).to be_a(Async::Job::Processor::Inline)
		expect(queue.server).to be_a(Async::Job::Processor::Inline)
	end
end
