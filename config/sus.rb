# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "covered/sus"
include Covered::Sus

# Redirect log output:
require "console/adapter/rails/logger"
require "active_job"
ActiveJob::Base.logger = ActiveSupport::TaggedLogging.new(
	Console::Adapter::Rails::Logger.new(Console)
)
