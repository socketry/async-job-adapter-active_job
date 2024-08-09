# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'test_job'
require 'async/job/adapter/active_job/executor'

require 'sus/fixtures/console/captured_logger'

describe Async::Job::Adapter::ActiveJob::Executor do
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:executor) {subject.new}
	
	with "test job" do
		let(:job) {TestJob.new}
		
		it "can execute job" do
			serialized = job.serialize
			
			executor.call(serialized)
		end
	end
	
	with "bad job" do
		let(:job) {BadJob.new}
		
		it "can execute job" do
			serialized = job.serialize
			
			executor.call(serialized)
			
			expect_console.to have_logged(severity: be == :error, message: be =~ /Error performing BadJob/)
		end
	end
	
	with "bad data" do
		it "fails to execute job" do
			serialized = {"job_class" => "bad"}
			
			executor.call(serialized)
			
			expect_console.to have_logged(
				severity: be == :error,
				event: have_keys(
					type: be == :failure,
					message: be =~ /wrong constant name bad/
				)
			)
		end
	end
end
