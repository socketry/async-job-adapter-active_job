# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

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
				end
			end
		end
	end
end
