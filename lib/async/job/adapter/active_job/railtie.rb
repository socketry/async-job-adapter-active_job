# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job'
require 'thread/local'

require_relative 'dispatcher'

Thread.attr_accessor :async_job_adapter_active_job_dispatcher

module Async
	module Job
		module Adapter
			module ActiveJob
				# A Rails-specific adapter for `ActiveJob` that allows you to use `Async::Job` as the backend.
				class Railtie < ::Rails::Railtie
					# The default pipeline for processing jobs, using the `Inline` backend.
					DEFAULT_PIPELINE = proc do
						queue Async::Job::Backend::Inline
					end
					
					def initialize
						@backends = {"default" => DEFAULT_PIPELINE}
						@aliases = {}
					end
					
					# The backends that are available for processing jobs.
					attr :backends
					
					# The aliases for the backends.
					attr :aliases
					
					# Define a new backend for processing jobs.
					# @parameter name [String] The name of the backend.
					# @parameter aliases [Array(String)] The aliases for the backend.
					# @parameter block [Proc] The block that defines the backend.
					def backend_for(name, *aliases, &block)
						@backends[name] = block
						
						if aliases.any?
							alias_for(name, *aliases)
						end
					end
					
					# Define an alias for a backend.
					def alias_for(name, *aliases)
						aliases.each do |alias_name|
							@aliases[alias_name] = name
						end
					end
					
					# Used for dispatching jobs to a thread-local backend to avoid thread-safety issues.
					class ThreadLocalDispatcher
						def initialize(backends, aliases)
							@backends = backends
							@aliases = aliases
						end
						
						# The dispatcher for the current thread.
						def dispatcher
							Thread.current.async_job_adapter_active_job_dispatcher ||= Dispatcher.new(@backends)
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
						# @parameter name [String] The name of the backend.
						def start(name)
							dispatcher.start(name)
						end
					end
					
					# Start the job server with the given name.
					def start(name = "default")
						config.active_job.queue_adapter.start(name)
					end
					
					DEFAULT_QUEUE_ADAPTER = ThreadLocalDispatcher.new(self.backends, self.aliases)
					
					config.async_job = self
					config.active_job.queue_adapter = DEFAULT_QUEUE_ADAPTER
				end
			end
		end
	end
end
