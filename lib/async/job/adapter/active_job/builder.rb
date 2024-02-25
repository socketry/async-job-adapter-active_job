# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'queue_adapter'
require_relative 'queue_handler'

module Async
	module Job
		module Adapter
			module ActiveJob
				class Builder
					Pipeline = Struct.new(:adapter, :queue)
					
					def initialize
						@enqueue = []
						@dequeue = []
						@handler = QueueHandler::DEFAULT
						
						@queue = nil
					end
					
					def enqueue(middleware)
						@enqueue << middleware
					end
					
					def queue(queue, *arguments, **options)
						# The handler is the output side of the queue, e.g. a QueueHandler or similar wrapper.
						# The queue itself is instantiated with the handler.
						@queue = ->(handler){queue.new(handler, *arguments, **options)}
					end
					
					def dequeue(middleware)
						@dequeue << middleware
					end
					
					def handler(handler)
						@handler = handler
					end
					
					def build
						# To construct the queue, we need the handler.
						handler = @handler
						
						# We then wrap the handler with the middleware in reverse order:
						@dequeue.reverse_each do |middleware|
							handler = middleware.new(handler)
						end
						
						# We can now construct the queue with the handler:
						queue = @queue.call(handler)
						
						adapter = queue
						
						# We now construct the queue adapter:
						adapter = @enqueue.reverse_each do |middleware|
							adapter = middleware.new(queue)
						end
						
						unless adapter.is_a?(QueueAdapter)
							adapter = QueueAdapter.new(adapter)
						end
						
						# The adapter is the part we provide to ActiveJob, and the handler is the part that actually executes the job:
						return Pipeline.new(adapter, queue)
					end
				end
			end
		end
	end
end
