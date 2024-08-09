# frozen_string_literal: true

require 'sus/fixtures/async/reactor_context'

require 'async/job'
require 'async/job/buffer'
require 'async/job/adapter/active_job/interface'

require_relative '../fixtures/test_job'

require 'benchmark'

describe Async::Job::Adapter::ActiveJob do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:buffer) {Async::Job::Buffer.new}
	
	let(:queue) do
		Async::Job::Builder.build(buffer) do
			enqueue Async::Job::Adapter::ActiveJob::Interface
			dequeue Async::Job::Processor::Redis
		end
	end
	
	before do
		TestQueueAdapter.set(queue.client)
	end
	
	it "should enqueue jobs" do
		measure = Benchmark.measure do
			Sync do
				1000.times do
					TestJob.perform_later
				end
			end
		end
		
		inform("Jobs/second: #{1000.0 / measure.utime}")
	end
end
