# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "json"

require "console"
require "console/event/failure"

require "active_job"
require "active_job/base"

module Async
	module Job
		module Adapter
			module ActiveJob
				# An executor for processing jobs using `ActiveJob`.
				class Executor
					# Initialize the executor with an optional delegate.
					# @parameter delegate [Object] An optional delegate object for handling lifecycle methods.
					def initialize(delegate = nil)
						@delegate = delegate
					end
					
					# Execute a job with the given data.
					# @parameter job_data [Hash] Serialized job data from ActiveJob.
					def execute(job_data)
						::ActiveJob::Callbacks.run_callbacks(:execute) do
							job = ::ActiveJob::Base.deserialize(job_data)
							
							begin
								job.perform_now
							rescue => error
								# Ignore, as ActiveJob has already logged the error.
							end
						end
					end
					
					# Execute the given job.
					def call(job)
						begin
							execute(job)
						rescue => error
							# Error handling is done by the job itself.
							# Ignore the error here, as ActiveJob has already logged unhandled errors.
							Console::Event::Failure.for(error).emit(self, "Failed to execute job!", job: job)
						end
						
						@delegate&.call(job)
					end
					
					# Start the delegate if present.
					def start
						@delegate&.start
					end
					
					# Stop the delegate if present.
					def stop
						@delegate&.stop
					end
					
					# The default executor, for use at the end of the queue.
					DEFAULT = self.new.freeze
				end
			end
		end
	end
end
