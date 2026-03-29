# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Carmine Paolino.

require "async/job/adapter/active_job/service"
require "fileutils"
require "tmpdir"

describe Async::Job::Adapter::ActiveJob::Service::HealthReporter do
	let(:ready_count) {Thread::Queue.new}
	let(:reporter) do
		subject.new(0.01) do
			ready_count << :ready
		end
	end
	
	it "sends health updates from a dedicated thread" do
		thread = reporter.start
		
		expect(thread).to be_a(Thread)
		
		deadline = Time.now + 0.2
		while ready_count.size < 2 && Time.now < deadline
			sleep(0.01)
		end
		
		expect(ready_count.size).to be >= 2
	ensure
		reporter.stop
	end
end

describe Async::Job::Adapter::ActiveJob::Service do
	let(:reporter_stops) {[]}
	let(:reporter) do
		Object.new.tap do |object|
			object.define_singleton_method(:stop) do
				reporter_stops << :stop
			end
		end
	end
	
	let(:instance) do
		Object.new.tap do |object|
			object.define_singleton_method(:ready!) {}
			object.define_singleton_method(:name=) {|value| value}
		end
	end
	
	let(:dispatcher) do
		Object.new.tap do |object|
			object.define_singleton_method(:status_string) {"idle"}
			object.define_singleton_method(:start) {|queue_name| queue_name}
		end
	end
	
	it "does not stop the health reporter immediately after setup" do
		Dir.mktmpdir do |root|
			current_dispatcher = dispatcher
			current_instance = instance
			current_reporter = reporter
			
			FileUtils.mkdir_p(File.join(root, "config"))
			File.write(File.join(root, "config/environment.rb"), "# test environment\n")
			
			evaluator = Object.new
			evaluator.define_singleton_method(:container_options) {{health_check_timeout: 1}}
			evaluator.define_singleton_method(:health_check_interval) {0.01}
			evaluator.define_singleton_method(:root) {root}
			evaluator.define_singleton_method(:dispatcher) {current_dispatcher}
			evaluator.define_singleton_method(:queue_names) {[]}
			evaluator.define_singleton_method(:name) {"test-service"}
			
			environment = Object.new
			environment.define_singleton_method(:evaluator) {evaluator}
			
			container = Object.new
			container.define_singleton_method(:run) do |name:, **options, &block|
				block.call(current_instance)
			end
			
			service = subject.new(environment, evaluator)
			service.define_singleton_method(:start_health_reporter) do |current_instance, interval:|
				current_reporter
			end
			
			service.setup(container)
		end
		
		expect(reporter_stops).to be(:empty?)
	end
end
