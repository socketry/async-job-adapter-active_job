# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job/adapter/active_job'
require 'async/job/backend/inline'
require 'async/job/buffer'

require 'sus/fixtures/async/reactor_context'
require 'test_job'

describe Async::Job::Adapter::ActiveJob do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:buffer) {Async::Job::Buffer.new}
	
	let(:pipeline) do
		Async::Job::Builder.build(buffer) do
			enqueue Async::Job::Adapter::ActiveJob::Interface
			queue Async::Job::Backend::Inline
		end
	end
	
	it "can schedule a job" do
		TestQueueAdapter.set(pipeline.producer)
		
		job = TestJob.perform_later
		
		expect(buffer.pop).to have_keys(
			"job_id"     => be == job.job_id,
			"job_class"  => be == "TestJob",
			"queue_name" => be == "default",
			"arguments"  => be == [], 
		)
	end
end
