# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'json'

module Async
	module Job
		module Adapter
			module ActiveJob
				class QueueHandler
					def initialize(coder = JSON)
						@coder = coder
					end
					
					def call(job)
						job = @coder.load(job)
						Console.info(self, "Calling job...", id: job[:job_id])
						::ActiveJob::Base.execute(job)
					end
					
					DEFAULT = self.new.freeze
				end
			end
		end
	end
end
