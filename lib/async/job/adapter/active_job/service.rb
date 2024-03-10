# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/service/generic'

module Async
	module Job
		module Adapter
			module ActiveJob
				class Service < Async::Service::Generic
					module Environment
						def service_class
							Service
						end
						
						def queue_name
							"default"
						end
					end
					
					def self.included(base)
						base.include(Environment)
					end
					
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
