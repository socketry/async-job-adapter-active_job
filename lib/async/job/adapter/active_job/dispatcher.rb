# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/job'
require 'thread/local'

require 'async/job/builder'

module Async
	module Job
		module Adapter
			module ActiveJob
				class Dispatcher
					def initialize(backends, aliases = {})
						@backends = backends
						@aliases = aliases
						
						@pipelines = {}
					end
					
					attr :backends
					
					attr :aliases
					
					def [](name)
						name = name.to_sym
						
						@pipelines.fetch(name) do
							backend = @backends.fetch(name)
							@pipelines[name] = build(backend)
						end
					end
					
					def enqueue(job)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].adapter.enqueue(job)
					end
					
					def enqueue_at(job, timestamp)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].adapter.enqueue_at(job, timestamp)
					end
					
					def start(name)
						self[name].queue.start
					end
					
					private def build(backend)
						builder = Builder.new(Executor::DEFAULT)
						
						builder.instance_eval(&backend)
						
						builder.build do |producer|
							# Ensure that the producer is an interface:
							unless producer.is_a?(Interface)
								Interface.new(producer)
							end
						end
					end
				end
			end
		end
	end
end
