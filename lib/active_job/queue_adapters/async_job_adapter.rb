# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "active_job/queue_adapters/abstract_adapter"

require "kernel/sync"

# @namespace
module ActiveJob
	# @namespace
	module QueueAdapters
		# ActiveJob adapter for async-job, providing asynchronous job processing capabilities.
		class AsyncJobAdapter < AbstractAdapter
			# Initialize the adapter with a dispatcher.
			# @parameter dispatcher [Object] The job dispatcher, defaults to the Railtie dispatcher.
			def initialize(dispatcher = ::Async::Job::Adapter::ActiveJob::Railtie.dispatcher)
				@dispatcher = dispatcher
			end
			
			# Enqueue a job for processing.
			def enqueue(job)
				Sync do
					@dispatcher.call(job)
				end
			end
			
			# Enqueue a job for processing at a specific time.
			def enqueue_at(job, timestamp)
				Sync do
					@dispatcher.call(job)
				end
			end
		end
	end
end
