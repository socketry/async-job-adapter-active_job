# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/service/generic'

module Async
	module Job
		module Adapter
			module ActiveJob
				# A job server that can be run as a service.
				class Service < Async::Service::Generic
					# Load the Rails environment and start the job server.
					def setup(container)
						container.run(name: self.name, restart: true) do |instance|
							evaluator = @environment.evaluator
							require File.expand_path('config/environment', evaluator.root)
							
							instance.ready!
							
							Sync do
								Railtie.start(evaluator.queue_name)
							end
						end
					end
				end
			end
		end
	end
end
