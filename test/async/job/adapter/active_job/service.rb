# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Carmine Paolino.

require "async/job/adapter/active_job/service"

describe Async::Job::Adapter::ActiveJob::Service::HealthReporter do
	let(:ready_count) {Thread::Queue.new}
	let(:reporter) do
		subject.new(0.01) do
			ready_count << :ready
		end
	end
	
	it "sends health updates from a dedicated thread" do
		thread = reporter.start
		
		expect(thread).to be_a(Thread)
		
		deadline = Time.now + 0.2
		while ready_count.size < 2 && Time.now < deadline
			sleep(0.01)
		end
		
		expect(ready_count.size).to be >= 2
	ensure
		reporter.stop
	end
end
