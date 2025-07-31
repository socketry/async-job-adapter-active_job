# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "async/job"
require "async/job/processor/inline"

require_relative "thread_local_dispatcher"

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
					
					# Initialize the railtie with default queue configuration.
					def initialize
						@definitions = {"default" => DEFAULT_QUEUE_DEFINITION}
						@aliases = {}
						
						@dispatcher = ThreadLocalDispatcher.new(@definitions, @aliases)
					end
					
					# The queues that are available for processing jobs.
					attr :definitions
					
					# The aliases for the definitions, if any.
					attr :aliases
					
					# Thed default dispatcher for processing jobs.
					attr :dispatcher
					
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
					
					# Start the job server with the given name.
					def start(name = "default")
						@dispatcher.start(name)
					end
					
					config.async_job = self
				end
			end
		end
	end
end
