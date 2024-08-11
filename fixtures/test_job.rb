# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'active_job'
require 'fiber/storage'

module TestQueueAdapter
	class Dispatcher
		def initialize(queues = {})
			@queues = queues
		end
		
		def call(job)
			@queues[job.queue_name].call(job.serialize)
		end
	end
	
	def self.set(...)
		Fiber[:active_job_test_queue_adapter] = Dispatcher.new(...)
	end
	
	def self.enqueue(job)
		Fiber[:active_job_test_queue_adapter].call(job)
	end
	
	def self.enqueue_at(job, timestamp)
		Fiber[:active_job_test_queue_adapter].call(job)
	end
end

class TestJob < ActiveJob::Base
	self.queue_adapter = TestQueueAdapter
	
	def perform(*arguments, **options)
		Console.debug(self, "Performing job...", arguments: arguments, options: options)
	end
end

class BadJob < ActiveJob::Base
	self.queue_adapter = TestQueueAdapter
	
	def perform(*arguments, **options)
		Console.debug(self, "Performing job...", arguments: arguments, options: options)
		raise "This job is bad!"
	end
end
