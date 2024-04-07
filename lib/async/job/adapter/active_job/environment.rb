# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'service'

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
					
					# The name of the queue to use.
					def queue_name
						"default"
					end
				end
			end
		end
	end
end
