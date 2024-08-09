# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

module Async
	module Job
		module Adapter
			module ActiveJob
				# An interface for `ActiveJob` that allows you to use `Async::Job` as the queue.
				class Interface
					def initialize(delegate)
						@delegate = delegate
					end
					
					# Enqueue a job for processing.
					def enqueue(job)
						Console.debug(self, "Enqueueing job...", id: job.job_id)
						@delegate.call(serialize(job))
					end
					
					# Enqueue a job for processing at a specific time.
					def enqueue_at(job, timestamp)
						# We assume the given timestamp is the same as `job.scheduled_at` which is true in every case we've seen so far.
						Console.debug(self, "Scheduling job...", id: job.job_id, scheduled_at: job.scheduled_at)
						@delegate.call(serialize(job))
					end
					
					protected
					
					def serialize(job)
						job.serialize
					end
				end
			end
		end
	end
end
