# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job'
require 'thread/local'

require_relative 'dispatcher'

class Thread
	attr_accessor :async_job_adapter_active_job_dispatcher
end

module Async
	module Job
		module Adapter
			module ActiveJob
				class Railtie < ::Rails::Railtie
					DEFAULT_REDIS = ->{
						Async::Job::Adapter::ActiveJob::QueueAdapter.new(
							Async::Job::Backend::Redis.new
						)
					}
					
					def initialize
						@backends = {default: DEFAULT_REDIS}
						@aliases = {}
					end
					
					attr :backends
					
					attr :aliases
					
					def backend_for(name, *aliases, &block)
						@backends[name] ||= block
						
						if aliases.any?
							alias_for(name, *aliases)
						end
					end
					
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
						
						def dispatcher
							Thread.current.async_job_adapter_active_job_dispatcher ||= Dispatcher.new(@backends)
						end
						
						def enqueue_at(job, timestamp)
							dispatcher.enqueue_at(job, timestamp)
						end
						
						def enqueue(job)
							dispatcher.enqueue(job)
						end
						
						def start(name)
							dispatcher.start(name)
						end
					end
					
					def start(name = :default)
						config.active_job.queue_adapter.start(name)
					end
					
					config.async_job = self
					config.active_job.queue_adapter = ThreadLocalDispatcher.new(self.backends, self.aliases)
				end
			end
		end
	end
end
