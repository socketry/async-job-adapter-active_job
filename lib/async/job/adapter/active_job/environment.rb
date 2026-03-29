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
					HEALTH_CHECK_TIMEOUT = "ASYNC_JOB_ADAPTER_ACTIVE_JOB_HEALTH_CHECK_TIMEOUT"
					HEALTH_CHECK_INTERVAL = "ASYNC_JOB_ADAPTER_ACTIVE_JOB_HEALTH_CHECK_INTERVAL"
					
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
					# @returns [Integer | nil]
					def count
						nil
					end
					
					# The maximum time a worker can go without a health update.
					# Set `ASYNC_JOB_ADAPTER_ACTIVE_JOB_HEALTH_CHECK_TIMEOUT=0` to disable health checks.
					def health_check_timeout(environment = ENV)
						parse_duration(environment, HEALTH_CHECK_TIMEOUT, default: 30, allow_disable: true)
					end
					
					# The interval between health updates.
					def health_check_interval(environment = ENV)
						if health_check_timeout = self.health_check_timeout(environment)
							parse_duration(environment, HEALTH_CHECK_INTERVAL, default: health_check_timeout / 2.0)
						end
					end
					
					# Options to use when creating the container.
					def container_options
						{
							restart: true,
							count: self.count,
							health_check_timeout: self.health_check_timeout,
						}.compact
					end
					
					private
					
					def parse_duration(environment, key, default:, allow_disable: false)
						if value = environment[key]
							duration = Float(value)
							
							return nil if allow_disable && duration <= 0
							return default if duration <= 0
							
							duration
						else
							default
						end
					end
				end
			end
		end
	end
end
