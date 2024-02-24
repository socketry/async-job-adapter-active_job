# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/service/generic'

module Async
	module Job
		module Adapter
			module ActiveJob
				class Service < Async::Service::Generic
					def self.each
						yield :service_class, self
					end
					
					def setup(container)
						container.run(name: self.name, restart: true) do |instance|
							require File.expand_path('config/environment', @environment.evaluator.root)
							
							instance.ready!
							
							Sync do
								Railtie::Dispatcher.instance.start
							end
						end
					end
				end
			end
		end
	end
end