# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'active_job/queue_adapters/abstract_adapter'

require 'kernel/sync'

module ActiveJob
	module QueueAdapters
		class AsyncJobAdapter < AbstractAdapter
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
