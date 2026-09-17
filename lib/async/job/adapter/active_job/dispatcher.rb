# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require_relative "executor"

require "async/job"
require "async/job/builder"

module Async
	module Job
		module Adapter
			module ActiveJob
				# A dispatcher for managing multiple definitions.
				class Dispatcher
					# Prepare the dispacher with the given definitions and aliases.
					# @parameter definitions [Hash(String, Proc)] The definitions to use constructing queues.
					# @parameter aliases [Hash(String, Proc)] The aliases for the definitions.
					def initialize(definitions = {}, aliases = {})
						@definitions = definitions
						@aliases = aliases
						
						@queues = {}
					end
					
					# @attribute [Hash(String, Proc)] The definitions to use for processing jobs.
					attr :definitions
					
					# @attribute [Hash(String, String)] The aliases for the definitions.
					attr :aliases
					
					# @attribute [Hash(String, Queue)] The queues that have been constructed.
					attr :queues
					
					# Look up a queue by name, constructing it if necessary using the given definition.
					# @parameter name [String] The name of the queue.
					def [](name)
						@queues.fetch(name) do
							definition = @definitions.fetch(name)
							@queues[name] = build(definition)
						end
					end
					
					# Dispatch a job to the appropriate queue.
					# @parameter job [ActiveJob::Base] The job to dispatch.
					def call(job)
						name = @aliases.fetch(job.queue_name, job.queue_name)
						
						self[name].client.call(job.serialize)
					end
					
					# Start processing jobs in the given queue.
					def start(name)
						self[name].server.start
					end
					
					# Stop a queue that was already constructed by this dispatcher.
					# Teardown must not build a queue whose startup failed before construction.
					def stop(name)
						@queues[name]&.stop
					end
					
					# Get the names of all available queue definitions.
					# @returns [Array<String>] The queue definition names.
					def keys
						@definitions.keys
					end
					
					# Generate a summary of the configured queues and their server status.
					# @returns [String] A comma-separated summary of all configured queues.
					def status_string
						self.keys.map do |name|
							queue = @queues[name]
							server = queue&.server
							
							if server&.respond_to?(:status_string)
								"#{name} #{server.status_string}"
							else
								name
							end
						end.join(", ")
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
