# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'json'

module Async
	module Job
		module Adapter
			module ActiveJob
				# An executor for processing jobs using `ActiveJob`.
				class Executor
					def initialize(delegate = nil)
						@delegate = delegate
					end
					
					# Execute the given job.
					def call(job)
						# Console.debug(self, "Executing job...", id: job["job_id"])
						::ActiveJob::Base.execute(job)
						
						@delegate&.call(job)
					end
					
					# The default executor, at the end of the pipeline.
					DEFAULT = self.new.freeze
				end
			end
		end
	end
end
