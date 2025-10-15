# frozen_string_literal: true

# Released under the MIT License.

require_relative "service"

module Async
	module Job
		module Adapter
			module ActiveJob
				module Recurring
					module Environment
						def service_class
							Service
						end
						
						def count
							1
						end
					end
				end
			end
		end
	end
end

