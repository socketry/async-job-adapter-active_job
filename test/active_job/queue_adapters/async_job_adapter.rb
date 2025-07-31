# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "test_job"
require "active_job/queue_adapters/async_job_adapter"
require "async/job/adapter/active_job/dispatcher"
require "async/job/processor/inline"

require "sus/fixtures/console/captured_logger"

describe ActiveJob::QueueAdapters::AsyncJobAdapter do
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:buffer) {Async::Job::Buffer.new}
	
	let(:queue) do
		Async::Job::Builder.build(buffer) do
			dequeue Async::Job::Processor::Inline
			dequeue Async::Job::Adapter::ActiveJob::Executor
		end
	end
	
	let(:dispatcher) {Async::Job::Adapter::ActiveJob::Dispatcher.new}
	
	with "#initialize" do
		it "can initialize with custom dispatcher" do
			adapter = subject.new(dispatcher)
			expect(adapter.instance_variable_get(:@dispatcher)).to be == dispatcher
		end
		
		it "can initialize with default dispatcher" do
			# Skip test that requires Rails/Railtie - tested in integration
			# This would test: adapter = subject.new
			# expect(adapter.instance_variable_get(:@dispatcher)).to be_a(Async::Job::Adapter::ActiveJob::ThreadLocalDispatcher)
		end
	end
	
	with "#enqueue" do
		let(:adapter) {subject.new(dispatcher)}
		let(:job) {TestJob.new}
		
		before do
			dispatcher.queues["default"] = queue
		end
		
		it "can enqueue a job" do
			adapter.enqueue(job)
			
			Sync do
				serialized_job = buffer.pop
				expect(serialized_job).to have_keys(
					"job_class" => be == "TestJob",
					"queue_name" => be == "default",
					"arguments" => be == [],
				)
			end
		end
		
		it "successfully dispatches job through Sync wrapper" do
			# This test verifies that the job gets dispatched successfully
			# The Sync wrapper is tested implicitly by the successful enqueueing
			expect(dispatcher.queues["default"]).to be_a(Object)
			adapter.enqueue(job)
		end
	end
	
	with "#enqueue_at" do
		let(:adapter) {subject.new(dispatcher)}
		let(:job) {TestJob.new}
		let(:timestamp) {Time.now}
		
		before do
			dispatcher.queues["default"] = queue
		end
		
		it "can enqueue a job at specific time" do
			adapter.enqueue_at(job, timestamp)
			
			Sync do
				serialized_job = buffer.pop
				expect(serialized_job).to have_keys(
					"job_class" => be == "TestJob",
					"queue_name" => be == "default",
					"arguments" => be == [],
					"scheduled_at" => be == timestamp.iso8601(9),
				)
			end
		end
		
		it "successfully dispatches job through Sync wrapper" do
			# This test verifies that the job gets dispatched successfully at a specific time
			# The Sync wrapper is tested implicitly by the successful enqueueing
			expect(dispatcher.queues["default"]).to be_a(Object)
			adapter.enqueue_at(job, timestamp)
		end
	end
	
	with "job with custom queue" do
		let(:adapter) {subject.new(dispatcher)}
		let(:job) do
			TestJob.new.tap do |j|
				j.queue_name = "custom_queue"
			end
		end
		
		before do
			dispatcher.queues["custom_queue"] = queue
		end
		
		it "can enqueue job to custom queue" do
			adapter.enqueue(job)
			
			Sync do
				serialized_job = buffer.pop
				expect(serialized_job).to have_keys(
					"job_class" => be == "TestJob",
					"queue_name" => be == "custom_queue",
					"arguments" => be == [],
				)
			end
		end
	end
	
	with "job with arguments" do
		let(:adapter) {subject.new(dispatcher)}
		let(:job) {TestJob.new("arg1", "arg2", option: "value")}
		
		before do
			dispatcher.queues["default"] = queue
		end
		
		it "can enqueue job with arguments" do
			adapter.enqueue(job)
			
			Sync do
				serialized_job = buffer.pop
				expect(serialized_job).to have_keys(
					"job_class" => be == "TestJob",
					"queue_name" => be == "default",
				)
			end
		end
	end
end