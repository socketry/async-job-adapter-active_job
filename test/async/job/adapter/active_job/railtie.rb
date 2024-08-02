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
		dispatcher = Async::Job::Adapter::ActiveJob::Dispatcher.new(subject.backends, subject.aliases)
		
		pipeline = dispatcher["default"]
		expect(pipeline.producer).to be_a(Async::Job::Adapter::ActiveJob::Interface)
		expect(pipeline.consumer).to be_a(Async::Job::Backend::Inline::Server)
	end
end
