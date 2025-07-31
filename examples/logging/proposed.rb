# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "active_job/execution"

module ActiveJob
	module Execution
		def perform_now
			# Guard against jobs that were persisted before we started counting executions by zeroing out nil counters
			self.executions = (executions || 0) + 1
			
			deserialize_arguments_if_needed
			
			_perform_job
		rescue Exception => error
			handled = rescue_with_handler(error)
			return handled if handled
			
			_default_discard(error)
		end
		
		private
		def _default_discard(error)
			instrument :discard, error: error do
				run_after_discard_procs(error)
			end
		end
	end
end
