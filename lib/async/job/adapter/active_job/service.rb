# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "async/service/generic"
require "console/event/failure"

require "async"
require "async/barrier"

module Async
	module Job
		module Adapter
			module ActiveJob
				# A job server that can be run as a service.
				class Service < Async::Service::Generic
					# Sends periodic health updates from a dedicated Ruby thread so health signaling
					# remains responsive even if the reactor is temporarily blocked by job code.
					class HealthReporter
						def initialize(interval, &block)
							@interval = interval
							@block = block
							@thread = nil
							@mutex = Mutex.new
							@condition = ConditionVariable.new
							@stop_requested = false
						end
						
						def start
							@mutex.synchronize do
								return false if @thread
								
								@stop_requested = false
								@thread = Thread.new do
									Thread.current.report_on_exception = false
									
									loop do
										break if wait_for_stop
										
										@block.call
									end
								rescue IOError, Errno::EPIPE
									# The parent container may have already closed the notification pipe.
								ensure
									@mutex.synchronize do
										@thread = nil if @thread.equal?(Thread.current)
									end
								end
							end
						end
						
						def stop
							thread = @mutex.synchronize do
								@stop_requested = true
								@condition.broadcast
								
								@thread
							end
							
							thread&.join unless thread == Thread.current
						end
						
						private
						
						def wait_for_stop
							@mutex.synchronize do
								return true if @stop_requested
								
								@condition.wait(@mutex, @interval)
								
								@stop_requested
							end
						end
					end
					
					# Load the Rails environment and start the job server.
					def setup(container)
						container_options = @evaluator.container_options
						health_check_timeout = container_options[:health_check_timeout]
						health_check_interval = if @evaluator.respond_to?(:health_check_interval)
							@evaluator.health_check_interval
						elsif health_check_timeout
							health_check_timeout / 2.0
						end
						
						container.run(name: self.name, **container_options) do |instance|
							evaluator = @environment.evaluator
							
							require File.expand_path("config/environment", evaluator.root)
							
							dispatcher = evaluator.dispatcher
							
							instance.ready!
							health_reporter = self.start_health_reporter(instance, interval: health_check_interval)
							
							Sync do |task|
								if health_check_timeout
									task.async(transient: true) do
										while true
											instance.name = "#{self.name} (#{dispatcher.status_string})"
											sleep(health_check_interval)
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
										Console::Event::Failure.for(error).emit(self, "Queue failed!")
									end
								end
								
								barrier.wait
							ensure
								barrier.stop
							end
						end
					end
					
					private
					
					def start_health_reporter(instance, interval:)
						return unless interval
						
						reporter = HealthReporter.new(interval) do
							instance.ready!
						end
						
						reporter.start
						reporter
					end
				end
			end
		end
	end
end
