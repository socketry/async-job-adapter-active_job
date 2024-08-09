# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'covered/sus'
include Covered::Sus

# Redirect log output:
require 'console/adapter/rails/logger'
require 'active_job'
ActiveJob::Base.logger = Console::Adapter::Rails::Logger.new(Console)
