# frozen_string_literal: true

# Released under the MIT License.

require "tmpdir"
require "yaml"
require "fugit"

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/console"

require "async/service/generic"
require "async"

require "async/job/adapter/active_job/recurring/service"
require "async/job/adapter/active_job/recurring/loader"
require "async/job/adapter/active_job/recurring/task"

describe Async::Job::Adapter::ActiveJob::Recurring::Service do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:service_class) {Async::Job::Adapter::ActiveJob::Recurring::Service}
	FakeEvaluator = Struct.new(:name, :health_check_timeout, keyword_init: true)
	FakeEnvironment = Struct.new(:evaluator, keyword_init: true)
	let(:loader_mod) {Async::Job::Adapter::ActiveJob::Recurring::Loader}
	let(:task_struct) {Async::Job::Adapter::ActiveJob::Recurring::Task}
	
	# A minimal container that records runs and provides a controllable task.
	class FakeInstance
		attr_reader :ready_calls
		def initialize
			@ready_calls = 0
		end
		def ready!
			@ready_calls += 1
		end
	end
	
	class FakeContainer
		attr_reader :tasks, :instances, :runs
		def initialize
			@tasks = []
			@instances = []
			@runs = []
		end
		
		# Mimic Async::Container#run(name:, count:) { |instance| ... }
		def run(name:, count: 1)
			@runs << {name:, count:}
			inst = FakeInstance.new
			@instances << inst
			# Execute the service logic within the reactor, but keep control to stop it.
			t = Async do
				yield inst
			end
			@tasks << t
			t
		end
	end
	
	# Ensure ENV is restored after each example.
	def with_env(updated)
		orig = ENV.to_h
		ENV.replace(orig.merge(updated))
		yield
		ensure
			ENV.replace(orig)
	end
	
	it "logs boot failure via ASYNC_JOB_BOOT and continues (rescue)" do
		Dir.mktmpdir("svc-spec-boot") do |root|
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test", "ASYNC_JOB_BOOT" => "no/such/file", "ASYNC_JOB_SKIP_RECURRING" => "true") do
				container = FakeContainer.new
				env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
				service_class.new(env).setup(container)
				
				# Confirm warning about boot failure was logged.
				expect_console.to have_logged(message: be(:include?, "Failed to boot application"))
				# Skip branch should mark instance ready.
				expect(container.instances.first.ready_calls).to be == 1
				# Clean up any running tasks.
				container.tasks.each(&:stop)
			end
		end
	end
	
	it "skips scheduler when ASYNC_JOB_SKIP_RECURRING=true" do
		Dir.mktmpdir("svc-spec-skip") do |root|
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test", "ASYNC_JOB_SKIP_RECURRING" => "true") do
				container = FakeContainer.new
				env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
				service_class.new(env).setup(container)
				
				expect_console.to have_logged(message: be(:include?, "Recurring scheduler disabled via env."))
				expect(container.instances.first.ready_calls).to be == 1
				container.tasks.each(&:stop)
			end
		end
	end
	
	it "skip branch completes immediately when sleep is stubbed" do
		Dir.mktmpdir("svc-spec-skip-fast") do |root|
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test", "ASYNC_JOB_SKIP_RECURRING" => "true") do
				# Temporarily stub Kernel.sleep to return immediately in this example:
				begin
					Kernel.singleton_class.alias_method(:__orig_sleep, :sleep)
					Kernel.define_singleton_method(:sleep) {|*| 0}
					
					container = FakeContainer.new
					env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
					service_class.new(env).setup(container)
					
					expect(container.instances.first.ready_calls).to be == 1
								ensure
									# Restore original sleep:
									Kernel.singleton_class.alias_method(:sleep, :__orig_sleep)
									Kernel.singleton_class.remove_method(:__orig_sleep) rescue nil
									container&.tasks&.each(&:stop)
				end
			end
		end
	end
	
	it "auto-detects and requires config/environment.rb when present" do
		Dir.mktmpdir("svc-spec-autoboot") do |root|
			# Create a minimal boot file that does nothing when required:
			FileUtils.mkdir_p(File.join(root, "config"))
			File.write(File.join(root, "config/environment.rb"), "# noop boot\n")
			
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test", "ASYNC_JOB_SKIP_RECURRING" => "true") do
				container = FakeContainer.new
				env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
				service_class.new(env).setup(container)
				
				# Should have skipped, but after attempting to require the boot file (no warning expected):
				expect(container.instances.first.ready_calls).to be == 1
				container.tasks.each(&:stop)
			end
		end
	end
	
	it "logs 'No recurring tasks loaded' when schedule file is missing" do
		Dir.mktmpdir("svc-spec-missing") do |root|
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test") do
				container = FakeContainer.new
				env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
				service_class.new(env).setup(container)
				
				expect_console.to have_logged(message: be(:include?, "No recurring tasks loaded (missing file)."))
				expect(container.instances.first.ready_calls).to be == 1
				container.tasks.each(&:stop)
			end
		end
	end
	
	it "logs 'No valid recurring tasks' when schedule present but invalid" do
		Dir.mktmpdir("svc-spec-invalid") do |root|
			# Write a schedule file with an invalid cron entry for env=test
			path = File.join(root, "config/recurring.yml")
			FileUtils.mkdir_p(File.dirname(path))
			File.write(path, <<~YAML)
        test:
          bad_task:
            class: 'ActiveJob::Base'
            schedule: 'not a valid cron'
						YAML
			
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test") do
				container = FakeContainer.new
				env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
				service_class.new(env).setup(container)
				
				expect_console.to have_logged(message: be(:include?, "No valid recurring tasks after parsing schedule."))
				expect(container.instances.first.ready_calls).to be == 1
				container.tasks.each(&:stop)
			end
		end
	end
	
	it "starts scheduler for valid tasks and logs task banner" do
		Dir.mktmpdir("svc-spec-ok") do |root|
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test") do
				# Stub loader to return one valid task without hitting filesystem.
				cron = Fugit.parse("*/1 * * * * *")
				task = task_struct.new(key: "example", klass: nil, command: nil, queue: "high", priority: 5, args: nil, cron: cron)
				
				backend = Async::Job::Adapter::ActiveJob::Recurring
				loader_orig = loader_mod.method(:load)
				scheduler_orig = backend.const_get(:Scheduler)
				
				begin
					loader_mod.define_singleton_method(:load) {|root:, env:| [task]}
					# Replace Scheduler with a stub that returns immediately.
					stub_scheduler = Class.new do
						DEFAULT_PREFIX = "test-prefix"
						def initialize(*); end
						def run; end
					end
					backend.send(:remove_const, :Scheduler)
					backend.const_set(:Scheduler, stub_scheduler)
					# Ensure DEFAULT_PREFIX exists on the installed constant path:
					backend::Scheduler.const_set(:DEFAULT_PREFIX, "test-prefix") unless backend::Scheduler.const_defined?(:DEFAULT_PREFIX)
					
					container = FakeContainer.new
					env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
					service_class.new(env).setup(container)
					
					expect_console.to have_logged(message: be(:include?, "Starting recurring scheduler."))
					# Per-task banner log:
					expect_console.to have_logged(message: be == "[scheduler] task")
					expect(container.instances.first.ready_calls).to be == 1
								ensure
									# Restore stubs
									backend.send(:remove_const, :Scheduler)
									backend.const_set(:Scheduler, scheduler_orig)
									backend.define_singleton_method(:load, loader_orig) rescue nil
									# Stop any tasks created by container
									container&.tasks&.each(&:stop)
				end
			end
		end
	end
	
	it "logs warning when reconciliation fails" do
		Dir.mktmpdir("svc-spec-reconcile-fail") do |root|
			with_env("RAILS_ROOT" => root, "ASYNC_JOB_ENV" => "test") do
				# Stub loader to return one valid task
				cron = Fugit.parse("*/1 * * * * *")
				task = task_struct.new(key: "example", klass: nil, command: nil, queue: "high", priority: 5, args: nil, cron: cron)
				
				backend = Async::Job::Adapter::ActiveJob::Recurring
				loader_orig = loader_mod.method(:load)
				reconciler_orig = backend.const_get(:Reconciler).method(:reconcile)
				scheduler_class = backend.const_get(:Scheduler)
				
				begin
					loader_mod.define_singleton_method(:load) {|root:, env:| [task]}
					# Stub Reconciler.reconcile to raise an error
					backend::Reconciler.define_singleton_method(:reconcile) {|*args| raise "Reconcile failed!"}
					# Stub Scheduler to return immediately without removing the class
					scheduler_class.define_method(:run) {}
					
					container = FakeContainer.new
					env = FakeEnvironment.new(evaluator: FakeEvaluator.new(name: "scheduler", health_check_timeout: nil))
					service_class.new(env).setup(container)
					
					# Should log warning about reconciliation failure
					expect_console.to have_logged(message: be(:include?, "Failed to reconcile recurring tasks."))
					# Should continue and start scheduler anyway
					expect_console.to have_logged(message: be(:include?, "Starting recurring scheduler."))
					expect(container.instances.first.ready_calls).to be == 1
								ensure
									# Restore stubs
									backend::Reconciler.define_singleton_method(:reconcile, reconciler_orig)
									loader_mod.define_singleton_method(:load, loader_orig)
									# Stop any tasks created by container
									container&.tasks&.each(&:stop)
				end
			end
		end
	end
end
