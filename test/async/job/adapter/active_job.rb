# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async'
require 'async/redis'
require 'active_job'

require 'sus/fixtures/async/reactor_context'

require 'async/job/backend'
require 'async/job/adapter/active_job'
require 'test_job'

describe Async::Job::Adapter::ActiveJob do
	include Sus::Fixtures::Async::ReactorContext
	
	def before
		super
		
		@server_task = Async do
			Async::Job::Adapter::ActiveJob::Railtie.start
		end
	end
	
	def after
		@server_task.stop
		
		super
	end
	
	it "can schedule a job" do
		job = TestJob.perform_later
	end
end
