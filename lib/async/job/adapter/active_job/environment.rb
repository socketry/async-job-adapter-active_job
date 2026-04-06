# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "service"

module Async
	module Job
		module Adapter
			module ActiveJob
				# The environment for the ActiveJob server.
				module Environment
					# The service class to use.
					def service_class
						Service
					end
					
					# The rails root.
					# @return [String]
					def root
						ENV.fetch("RAILS_ROOT", Dir.pwd)
					end
					
					# Get the default dispatcher instance.
					# @returns [Object] The dispatcher from the Railtie.
					def dispatcher
						Railtie.dispatcher
					end
					
					# The name of the queue to use.
					def queue_names
						if queue_names = ENV["ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES"]
							queue_names.split(",")
						else
							dispatcher.keys
						end
					end
					
					# Number of instances to start. By default (when nil), uses `Etc.nprocessors`.
					# You can override via `ASYNC_JOB_WORKERS` or `JOBS_COUNT`.
					# In development, defaults to 1 if not specified.
					# @returns [Integer | nil]
					def count
						if workers = (ENV["ASYNC_JOB_WORKERS"] || ENV["JOBS_COUNT"]) 
							Integer(workers)
						elsif defined?(::Rails) && ::Rails.env.development?
							1
						else
							nil
						end
					end
					
					# Options to use when creating the container.
					def container_options
						{
							restart: true,
							count: self.count,
							health_check_timeout: 30,
						}.compact
					end
				end
			end
		end
	end
end
