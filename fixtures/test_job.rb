class TestJob < ActiveJob::Base
	queue_as :default

	def perform(*arguments, **options)
		Console.debug(self, "Performing job...", arguments: arguments, options: options)
	end
end