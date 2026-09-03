# frozen_string_literal: true

# Released under the MIT License.

require "async/job/adapter/active_job/service"

require "async/idler"

require "sus/fixtures/console/captured_logger"

describe Async::Job::Adapter::ActiveJob::Service do
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:dispatcher) {Object.new}
	# `Service#setup` requires config/environment from the evaluator root.
	# This fixture lets the lifecycle test run without a Rails application.
	let(:fixtures_root) {File.expand_path("../../../../../fixtures", __dir__)}
	
	let(:evaluator) do
		root = fixtures_root
		queue_dispatcher = dispatcher
		queue_dispatcher.define_singleton_method(:status_string){"default"}
		
		Object.new.tap do |evaluator|
			evaluator.define_singleton_method(:name){"test-service"}
			evaluator.define_singleton_method(:container_options){{count: 1, restart: true, health_check_timeout: 30}}
			evaluator.define_singleton_method(:root){root}
			evaluator.define_singleton_method(:dispatcher){queue_dispatcher}
			evaluator.define_singleton_method(:queue_names){["default"]}
		end
	end
	
	let(:environment) do
		service_evaluator = evaluator
		
		Object.new.tap do |environment|
			environment.define_singleton_method(:evaluator){service_evaluator}
		end
	end
	
	let(:container) do
		Object.new.tap do |container|
			container.define_singleton_method(:run) do |**options, &block|
				@options = options
				@block = block
			end
			
			container.define_singleton_method(:block){@block}
		end
	end
	
	let(:instance) do
		Object.new.tap do |instance|
			instance.define_singleton_method(:ready!){}
			instance.define_singleton_method(:name=){|name|}
		end
	end
	
	let(:service) {subject.new(environment, evaluator)}
	
	before do
		dispatcher.define_singleton_method(:stop){|name|}
		service.setup(container)
	end
	
	it "propagates queue task failures" do
		dispatcher.define_singleton_method(:start) do |name|
			Async(transient: true) do
				raise "Redis fetch failed"
			end
		end
		expect(dispatcher).to receive(:stop).with("default")
		
		expect do
			container.block.call(instance)
		end.to raise_exception(RuntimeError, message: be == "Redis fetch failed")
		
		expect_console.to have_logged(message: be == "Queue failed!", queue_name: be == "default")
	end
	
	it "stops sibling queue tasks before propagating failures" do
		sibling_task = nil
		
		dispatcher.define_singleton_method(:start) do |name|
			sibling_task = Async::Idler.new.async do
				sleep
			end
			
			Async(transient: true) do
				raise "Redis fetch failed"
			end
		end
		
		dispatcher.define_singleton_method(:stop) do |name|
			sibling_task.stop
			sibling_task.wait if sibling_task.alive?
		end
		
		expect do
			container.block.call(instance)
		end.to raise_exception(RuntimeError, message: be == "Redis fetch failed")
		
		expect(sibling_task.finished?).to be == true
	end
	
	it "keeps queues without a waitable task running" do
		dispatcher.define_singleton_method(:start){|name| true}
		
		Sync do |task|
			service_task = task.async do
				container.block.call(instance)
			end
			sleep(0)
			
			expect(service_task.status).to be == :running
			
			service_task.stop
			expect(service_task.wait).to be_nil
			expect_console.not.to have_logged(message: be == "Queue failed!")
		ensure
			service_task&.stop unless service_task&.finished?
		end
	end
end
