# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'executor'
require_relative 'interface'

require 'async/job'
require 'thread/local'
require 'async/job/builder'

module Async
	module Job
		module Adapter
			module ActiveJob
				# A dispatcher for managing multiple backends.
				class Dispatcher
					# Prepare the dispacher with the given backends and aliases.
					# @parameter backends [Hash(String, Proc)] The backends to use for processing jobs.
					# @parameter aliases [Hash(String, Proc)] The aliases for the backends.
					def initialize(backends, aliases = {})
						@backends = backends
						@aliases = aliases
						
						@pipelines = {}
					end
					
					# @attribute [Hash(String, Proc)] The backends to use for processing jobs.
					attr :backends
					
					# @attribute [Hash(String, String)] The aliases for the backends.
					attr :aliases
					
					# Lookup a pipeline by name, constructing it if necessary using the given backend.
					# @parameter name [String] The name of the pipeline/backend.
					def [](name)
						@pipelines.fetch(name) do
							backend = @backends.fetch(name)
							@pipelines[name] = build(backend)
						end
					end
					
					# Enqueue a job for processing.
					def enqueue(job)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].producer.enqueue(job)
					end
					
					# Enqueue a job for processing at a specific time.
					def enqueue_at(job, timestamp)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].producer.enqueue_at(job, timestamp)
					end
					
					# Start processing jobs in the given pipeline.
					def start(name)
						self[name].consumer.start
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
