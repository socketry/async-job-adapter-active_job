# frozen_string_literal: true

# Released under the MIT License.

require "async/job/adapter/active_job/recurring/environment"

describe Async::Job::Adapter::ActiveJob::Recurring::Environment do
	# Create a test class that includes the module
	let(:test_class) do
		Class.new do
			include Async::Job::Adapter::ActiveJob::Recurring::Environment
		end
	end
	
	let(:test_instance) {test_class.new}
	
	it "returns Service class from service_class method" do
		expect(test_instance.service_class).to be == Async::Job::Adapter::ActiveJob::Recurring::Service
	end
	
	it "returns 1 from count method" do
		expect(test_instance.count).to be == 1
	end
end
