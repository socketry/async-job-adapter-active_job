# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job'

require 'thread/local'

module Async
	module Job
		module Adapter
			module ActiveJob
				class Dispatcher
					def initialize(backends, aliases = {})
						@backends = backends
						@aliases = aliases
						
						@queue_adapters = {}
					end
					
					attr :backends
					
					attr :aliases
					
					def [](name)
						@queue_adapters.fetch(name) do
							backend = @backends.fetch(name)
							@queue_adapters[name] = backend.call
						end
					end
					
					def enqueue(job)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].enqueue(job)
					end
					
					def enqueue_at(job, timestamp)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].enqueue_at(job, timestamp)
					end
					
					def start(name)
						self[name].start
					end
				end
			end
		end
	end
end
