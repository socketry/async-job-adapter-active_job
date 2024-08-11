# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "active_job/version"
require_relative "active_job/executor"

if defined?(Rails::Railtie)
	require_relative "active_job/railtie"
	require "active_job/queue_adapters/async_job_adapter"
end
