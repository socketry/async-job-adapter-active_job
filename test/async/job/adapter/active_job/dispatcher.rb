# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'test_job'
require 'active_job/queue_adapters/async_job_adapter'
require 'async/job/adapter/active_job/dispatcher'
require 'async/job/processor/inline'

require 'sus/fixtures/console/captured_logger'

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
end
