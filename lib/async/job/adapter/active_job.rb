# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'active_job/version'
require_relative 'active_job/interface'
require_relative 'active_job/executor'
require_relative "active_job/railtie" if defined?(Rails::Railtie)
