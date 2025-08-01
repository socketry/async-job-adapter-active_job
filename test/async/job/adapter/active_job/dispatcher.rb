# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "test_job"
require "active_job/queue_adapters/async_job_adapter"
require "async/job/adapter/active_job/dispatcher"
require "async/job/processor/inline"

require "sus/fixtures/console/captured_logger"

describe Async::Job::Adapter::ActiveJob::Dispatcher do
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:buffer) {Async::Job::Buffer.new}
	
	let(:queue) do
		Async::Job::Builder.build(buffer) do
			dequeue Async::Job::Processor::Inline
			dequeue Async::Job::Adapter::ActiveJob::Executor
		end
	end
	
	let(:dispatcher) {subject.new}
	
	let(:queue_adapter) {ActiveJob::QueueAdapters::AsyncJobAdapter.new(dispatcher)}
	
	with "test job" do
		before do
			dispatcher.queues["default"] = queue
		end
		
		it "can dispatch job" do
			# Without Sync/Async:
			queue_adapter.enqueue(TestJob.new)
			
			Sync do
				expect(buffer.pop).to have_keys(
					"job_class" => be == "TestJob",
					"queue_name" => be == "default",
					"arguments" => be == [],
				)
			end
		end
	end
	
	with "#start" do
		it "can start queue server" do
			mock_server = Object.new
			mock_server.define_singleton_method(:start) {}
			
			mock_queue = Object.new
			mock_queue.define_singleton_method(:server) {mock_server}
			
			dispatcher.queues["test_queue"] = mock_queue
			
			expect(mock_server).to receive(:start)
			dispatcher.start("test_queue")
		end
	end
	
	with "#keys" do
		it "can get definition keys" do
			keys = dispatcher.keys
			expect(keys).to be == []
		end
	end
	
	with "#defintions" do
		it "can add definitions" do
			dispatcher.definitions[:test_queue] = proc do
				Async::Job::Builder.new(
					Async::Job::Processor::Inline.new(nil)
				).build
			end
			
			expect(dispatcher.keys).to be == [:test_queue]
			
			expect(dispatcher[:test_queue]).to be_a(Async::Job::Queue)
			
			expect(dispatcher.status_string).to be == "test_queue"
		end
	end
	
	with "#status_string" do
		it "returns a status string for all queues" do
			dispatcher.definitions["test_queue"] = Object.new
			
			expect(dispatcher.status_string).to be == "test_queue"
		end
	end
end
