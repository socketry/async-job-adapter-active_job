# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job'
require 'async/job/processor/inline'

require_relative 'dispatcher'

Thread.attr_accessor :async_job_adapter_active_job_dispatcher

module Async
	module Job
		module Adapter
			module ActiveJob
				# A Rails-specific adapter for `ActiveJob` that allows you to use `Async::Job` as the queue.
				class Railtie < ::Rails::Railtie
					# The default queue definition for processing jobs, using the `Inline` backend.
					DEFAULT_QUEUE_DEFINITION = proc do
						dequeue Processor::Inline
					end
					
					def initialize
						@definitions = {"default" => DEFAULT_QUEUE_DEFINITION}
						@aliases = {}
					end
					
					# The queues that are available for processing jobs.
					attr :definitions
					
					# The aliases for the definitions, if any.
					attr :aliases
					
					# Define a new backend for processing jobs.
					# @parameter name [String] The name of the backend.
					# @parameter aliases [Array(String)] The aliases for the backend.
					# @parameter block [Proc] The block that defines the backend.
					def define_queue(name, *aliases, &block)
						name = name.to_s
						
						@definitions[name] = block
						
						if aliases.any?
							alias_queue(name, *aliases)
						end
					end
					
					# Define an alias for a queue.
					def alias_queue(name, *aliases)
						aliases.each do |alias_name|
							alias_name = alias_name.to_s
							
							@aliases[alias_name] = name
						end
					end
					
					# Used for dispatching jobs to a thread-local queue to avoid thread-safety issues.
					class ThreadLocalDispatcher
						def initialize(definitions, aliases)
							@definitions = definitions
							@aliases = aliases
						end
						
						# The dispatcher for the current thread.
						def dispatcher
							Thread.current.async_job_adapter_active_job_dispatcher ||= Dispatcher.new(@definitions, @aliases)
						end
						
						# Enqueue a job to be processed at a specific time.
						def enqueue_at(job, timestamp)
							dispatcher.enqueue_at(job, timestamp)
						end
						
						# Enqueue a job to be processed as soon as possible.
						def enqueue(job)
							dispatcher.enqueue(job)
						end
						
						# Start processing jobs in the queue with the given name.
						# @parameter name [String] The name of the queue.
						def start(name)
							dispatcher.start(name)
						end
					end
					
					# Start the job server with the given name.
					def start(name = "default")
						config.active_job.queue_adapter.start(name)
					end
					
					DEFAULT_DISPATCHER = ThreadLocalDispatcher.new(self.definitions, self.aliases)
					
					config.async_job = self
					
					config.active_job.queue_adapter = DEFAULT_DISPATCHER
				end
			end
		end
	end
end
