# frozen_string_literal: true

# Released under the MIT License.

require_relative "service"

module Async
	module Job
		module Adapter
			module ActiveJob
				# Provides recurring job scheduling functionality.
				module Recurring
					# Environment configuration for the recurring scheduler service.
					module Environment
						# The service class to use for recurring scheduling.
						# @returns [Class] The Service class.
						def service_class
							Service
						end
						
						# The number of recurring scheduler instances to run.
						# @returns [Integer] The count (always 1).
						def count
							1
						end
					end
				end
			end
		end
	end
end

