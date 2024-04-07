# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'active_job'
require 'fiber/storage'

module TestQueueAdapter
	def self.set(queue_adapter)
		Fiber[:active_job_test_queue_adapter] = queue_adapter
	end
	
	def self.enqueue(job)
		Fiber[:active_job_test_queue_adapter].enqueue(job)
	end
	
	def self.enqueue_at(job, timestamp)
		Fiber[:active_job_test_queue_adapter].enqueue_at(job, timestamp)
	end
end

class TestJob < ActiveJob::Base
	self.queue_adapter = TestQueueAdapter
	
	def perform(*arguments, **options)
		Console.debug(self, "Performing job...", arguments: arguments, options: options)
	end
end
