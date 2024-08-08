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
				# A dispatcher for managing multiple definitions.
				class Dispatcher
					# Prepare the dispacher with the given definitions and aliases.
					# @parameter definitions [Hash(String, Proc)] The definitions to use constructing queues.
					# @parameter aliases [Hash(String, Proc)] The aliases for the definitions.
					def initialize(definitions, aliases = {})
						@definitions = definitions
						@aliases = aliases
						
						@queues = {}
					end
					
					# @attribute [Hash(String, Proc)] The definitions to use for processing jobs.
					attr :definitions
					
					# @attribute [Hash(String, String)] The aliases for the definitions.
					attr :aliases
					
					# Lookup a pipeline by name, constructing it if necessary using the given backend.
					# @parameter name [String] The name of the pipeline/backend.
					def [](name)
						@queues.fetch(name) do
							definition = @definitions.fetch(name)
							@queues[name] = build(definition)
						end
					end
					
					# Enqueue a job for processing.
					def enqueue(job)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].client.enqueue(job)
					end
					
					# Enqueue a job for processing at a specific time.
					def enqueue_at(job, timestamp)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].client.enqueue_at(job, timestamp)
					end
					
					# Start processing jobs in the given pipeline.
					def start(name)
						self[name].server.start
					end
					
					private def build(definition)
						builder = Builder.new(Executor::DEFAULT)
						
						builder.instance_eval(&definition)
						
						builder.build do |client|
							# Ensure that the client is an interface:
							unless client.is_a?(Interface)
								Interface.new(client)
							end
						end
					end
				end
			end
		end
	end
end
