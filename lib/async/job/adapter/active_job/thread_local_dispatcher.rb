# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "dispatcher"

Thread.attr_accessor :async_job_adapter_active_job_dispatcher

module Async
	module Job
		module Adapter
			module ActiveJob
				# Used for dispatching jobs to a thread-local queue to avoid thread-safety issues.
				class ThreadLocalDispatcher
					def initialize(definitions, aliases)
						@definitions = definitions
						@aliases = aliases
					end
					
					# @attribute [Hash(String, Proc)] The definitions to use for creating queues.
					attr :definitions
					
					# @attribute [Hash(String, String)] The aliases for the job queues.
					attr :aliases
					
					# The dispatcher for the current thread.
					#
					# As a dispatcher contains state, it is important to ensure that each thread has its own dispatcher.
					def dispatcher
						Thread.current.async_job_adapter_active_job_dispatcher ||= Dispatcher.new(@definitions, @aliases)
					end
					
					def [](name)
						dispatcher[name]
					end
					
					def call(job)
						dispatcher.call(job)
					end
					
					# Start processing jobs in the queue with the given name.
					# @parameter name [String] The name of the queue.
					def start(name)
						dispatcher.start(name)
					end
					
					# The names of all the queues that are available for processing jobs.
					def keys
						@definitions.keys
					end
				end
			end
		end
	end
end
