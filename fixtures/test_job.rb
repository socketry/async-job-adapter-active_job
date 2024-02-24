# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

class TestJob < ActiveJob::Base
	queue_as :default

	def perform(*arguments, **options)
		Console.debug(self, "Performing job...", arguments: arguments, options: options)
	end
end
