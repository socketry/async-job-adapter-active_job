# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'executor'

require 'async/job'
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
					
					# Look up a queue by name, constructing it if necessary using the given definition.
					# @parameter name [String] The name of the queue.
					def [](name)
						@queues.fetch(name) do
							definition = @definitions.fetch(name)
							@queues[name] = build(definition)
						end
					end
					
					def call(job)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].client.call(job.serialize)
					end
					
					# Start processing jobs in the given queue.
					def start(name)
						self[name].server.start
					end
					
					def keys
						@definitions.keys
					end
					
					private def build(definition)
						builder = Builder.new(Executor::DEFAULT)
						
						builder.instance_eval(&definition)
						
						return builder.build
					end
				end
			end
		end
	end
end
