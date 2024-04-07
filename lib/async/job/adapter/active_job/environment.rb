# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'service'

module Async
	module Job
		module Adapter
			module ActiveJob
				module Environment
					def service_class
						Service
					end
					
					def queue_name
						"default"
					end
				end
			end
		end
	end
end
