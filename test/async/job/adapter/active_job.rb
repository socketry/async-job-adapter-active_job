# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job/adapter/active_job'
require 'async/job/processor/inline'
require 'async/job/buffer'

require 'sus/fixtures/async/reactor_context'
require 'sus/fixtures/console/captured_logger'
require 'test_job'

describe Async::Job::Adapter::ActiveJob do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:buffer) {Async::Job::Buffer.new}
	
	let(:queue) do
		Async::Job::Builder.build(buffer) do
			enqueue Async::Job::Adapter::ActiveJob::Interface
			dequeue Async::Job::Processor::Inline
			dequeue Async::Job::Adapter::ActiveJob::Executor
		end
	end
	
	it "can schedule a job" do
		TestQueueAdapter.set(queue.client)
		
		job = TestJob.perform_later
		
		expect(buffer.pop).to have_keys(
			"job_id"     => be == job.job_id,
			"job_class"  => be == "TestJob",
			"queue_name" => be == "default",
			"arguments"  => be == [], 
		)
	end
	
	it "retries a failed job" do
		TestQueueAdapter.set(queue.client)
		
		job = BadJob.perform_later
		
		expect(buffer.pop).to have_keys(
			"job_id"     => be == job.job_id,
			"job_class"  => be == "BadJob",
			"queue_name" => be == "default",
			"arguments"  => be == [],
		)
		
		expect_console.to have_logged(
			message: be =~ /Error performing BadJob/,
		)
	end
end
