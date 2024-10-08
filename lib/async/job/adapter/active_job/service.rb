# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'async/service/generic'
require 'console/event/failure'
require 'async/barrier'

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
							
							dispatcher = evaluator.dispatcher
							
							instance.ready!
							
							Sync do |task|
								barrier = Async::Barrier.new
								
								# Start all the named queues:
								evaluator.queue_names.each do |queue_name|
									barrier.async do
										Console.debug(self, "Starting queue...", queue_name: queue_name)
										dispatcher.start(queue_name)
									rescue => error
										Console::Event::Failure.for(error).emit(self, "Queue failed!")
									end
								end
								
								barrier.wait
							ensure
								barrier.stop
							end
						end
					end
				end
			end
		end
	end
end
