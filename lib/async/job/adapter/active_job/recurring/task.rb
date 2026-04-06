# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "fugit"

module Async
	module Job
		module Adapter
			module ActiveJob
				module Recurring
					# Represents a single recurring task loaded from config/recurring.yml.
					Task = Struct.new(:key, :klass, :command, :queue, :priority, :args, :cron, keyword_init: true)
					
					# Helper methods for parsing and processing recurring task configuration.
					module Helper
						module_function
						
						# Normalize simple natural schedules to a cron string that Fugit::Cron understands.
						def normalize_schedule(spec)
							s = spec.to_s.strip
							return s if s.empty?
							
							if (m = s.match(/\Aevery\s+(\d+)\s*seconds?\z/i))
								"*/#{Integer(m[1])} * * * * *"
							elsif (m = s.match(/\Aevery\s+(\d+)\s*minutes?\z/i))
								"0 */#{Integer(m[1])} * * * *"
							elsif (m = s.match(/\Aevery\s+(\d+)\s*hours?\z/i))
								"0 0 */#{Integer(m[1])} * * *"
							else
								s
							end
						end
						
						# Parse a cron expression string into a Fugit::Cron object.
						# @parameter s [String] The cron expression to parse.
						# @returns [Fugit::Cron, nil] The parsed cron object or nil if invalid.
						def parse_cron(s)
							cron = Fugit.parse(s)
							cron.is_a?(Fugit::Cron) ? cron : nil
						end
						
						# Resolve a constant name string to its class/module object.
						# @parameter name [String] The constant name (e.g., "MyJob" or "Foo::Bar").
						# @returns [Class, Module, nil] The constant or nil if not found.
						def constantize(name)
							name.to_s.split("::").inject(Object) {|m, part| m.const_get(part)}
														rescue NameError
															nil
						end
					end
				end
			end
		end
	end
end

