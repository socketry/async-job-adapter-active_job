# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'thread/local'
require 'async/redis/client'
require 'async/job/backend/redis/server'

module Async
	module Job
		module Adapter
			module ActiveJob
				class Railtie < ::Rails::Railtie
					module Dispatcher
						extend Thread::Local
						
						def self.local
							# We should load configuration from the Railtie...
							
							client = Async::Redis::Client.new
							server = Async::Job::Backend::Redis::Server.new(client, "async:job:active_job")
							
							return QueueAdapter.new(server)
						end
						
						def self.enqueue(job)
							self.instance.enqueue(job)
						end
						
						def self.enqueue_at(job, timestamp)
							self.instance.enqueue_at(job, timestamp)
						end
					end
					
					config.active_job.queue_adapter = Dispatcher
				end
			end
		end
	end
end
