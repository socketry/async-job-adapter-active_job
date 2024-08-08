# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'active_job/railtie'
require 'async/job/adapter/active_job/railtie'

describe Async::Job::Adapter::ActiveJob::Railtie do
	it "can create an instance" do
		expect(subject.config.active_job.queue_adapter).to be_a(Async::Job::Adapter::ActiveJob::Railtie::ThreadLocalDispatcher)
	end
	
	it "defaults to inline backend" do
		dispatcher = Async::Job::Adapter::ActiveJob::Dispatcher.new(subject.definitions, subject.aliases)
		
		queue = dispatcher["default"]
		expect(queue.client).to be_a(Async::Job::Adapter::ActiveJob::Interface)
		expect(queue.server).to be_a(Async::Job::Processor::Inline)
	end
end
