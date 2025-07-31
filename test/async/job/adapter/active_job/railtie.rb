# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "active_job/railtie"
require "async/job/adapter/active_job"

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
	
	with "#define_queue" do
		it "can define a queue with name conversion" do
			block = proc{"test definition"}
			
			subject.define_queue(:test_queue, &block)
			expect(subject.definitions["test_queue"]).to be == block
		end
		
		it "can define a queue with aliases" do
			block = proc{"test definition"}
			
			subject.define_queue("main_queue", "alias1", "alias2", &block)
			
			expect(subject.definitions["main_queue"]).to be == block
			expect(subject.aliases["alias1"]).to be == "main_queue"
			expect(subject.aliases["alias2"]).to be == "main_queue"
		end
	end
	
	with "#alias_queue" do
		it "can create queue aliases" do
			subject.alias_queue("main", "alias_a", "alias_b")
			
			expect(subject.aliases["alias_a"]).to be == "main"
			expect(subject.aliases["alias_b"]).to be == "main"
		end
	end
end
