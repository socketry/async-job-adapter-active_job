# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "async/service/generic"
require "console/event/failure"

require "async"
require "async/barrier"
require "async/notification"

module Async
	module Job
		module Adapter
			module ActiveJob
				# A job server that can be run as a service.
				class Service < Async::Service::Generic
					# Load the Rails environment and start the job server.
					def setup(container)
						container_options = @evaluator.container_options
						health_check_timeout = container_options[:health_check_timeout]
						drain_timeout = @evaluator.drain_timeout

						container.run(name: self.name, **container_options) do |instance|
							evaluator = @environment.evaluator

							require File.expand_path("config/environment", evaluator.root)

							dispatcher = evaluator.dispatcher

							instance.ready!

							Sync do |task|
								if health_check_timeout
									task.async(transient: true) do
										while true
											instance.name = "#{self.name} (#{dispatcher.status_string})"
											sleep(health_check_timeout / 2)
											instance.ready!
										end
									end
								end

								barrier = Async::Barrier.new

								# Start all the named queues:
								evaluator.queue_names.each do |queue_name|
									barrier.async do
										Console.debug(self, "Starting queue...", queue_name: queue_name)
										dispatcher.start(queue_name)
									rescue => error
										Console.error(self, "Failed to start queue!", queue_name: queue_name, exception: error)
									end
								end

								if drain_timeout
									# A stop signal unwinds the reactor before any rescue can run (the scheduler turns it into a root task stop), so to drain we must intercept the signal itself. A self-pipe wakes a task which stops the queues from fetching, waits for running jobs to finish, then shuts down. Jobs that outlive the timeout are cancelled and recovered as abandoned jobs, as before.
									reader, writer = ::IO.pipe

									%w[INT TERM].each do |signal|
										::Signal.trap(signal) do
											writer.write_nonblock(".")
										rescue ::IO::WaitWritable, ::IOError
											# Already draining or shutting down.
										end
									end

									shutdown = Async::Notification.new
									drained = false

									task.async(transient: true, annotation: "Draining on stop signal.") do
										reader.read(1)

										evaluator.queue_names.each do |queue_name|
											server = dispatcher[queue_name].server

											if server.respond_to?(:drain)
												Console.info(self, "Draining queue...", queue_name: queue_name, timeout: drain_timeout)
												server.drain(timeout: drain_timeout)
											end
										end

										drained = true
										shutdown.signal
									end

									# The queue tasks above do not finish (the processors' background loops are their children), so wait for the drain instead:
									shutdown.wait unless drained
								else
									barrier.wait or sleep
								end
							ensure
								barrier&.stop
							end
						end
					end
				end
			end
		end
	end
end
