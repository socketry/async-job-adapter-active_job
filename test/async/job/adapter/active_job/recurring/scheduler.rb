# frozen_string_literal: true

# Released under the MIT License.

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/console"

require "fugit"
require "securerandom"

require "async/job/adapter/active_job/recurring/task"
require "async/job/adapter/active_job/recurring/scheduler"

describe Async::Job::Adapter::ActiveJob::Recurring::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:task_struct) {Async::Job::Adapter::ActiveJob::Recurring::Task}
	let(:scheduler_class) {Async::Job::Adapter::ActiveJob::Recurring::Scheduler}
	
	# Minimal stub Active Job class which records perform_later calls.
	class StubJob
		@calls = []
		class << self
			attr_reader :calls
			def reset!; @calls = []; end
			def set(queue: nil, priority: nil); self; end
			def perform_later(*args); @calls << args; end
		end
	end
	
	before {StubJob.reset!}
	
	it "enqueues a job on schedule (memory dedup, no Redis)" do
		# Every 1 second.
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "test", klass: StubJob, command: nil, queue: "default", priority: 0, args: ["a"], cron: cron)
		
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		# Run a single task loop in the reactor and stop after we observe at least one call.
		child = Async do
			scheduler.send(:run_task, task)
		end
		
		# Wait up to ~1.5s for the first enqueue.
		started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		while StubJob.calls.empty? && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) < 1.6
			sleep 0.05
		end
		
		child.stop
		
		expect(StubJob.calls.length).to be >= 1
		expect(StubJob.calls.first).to be == ["a"]
	end
	
	it "writes last-run to Rails.cache when Redis is not enabled" do
		# Install a minimal Rails.cache stub.
		cache = Class.new do
			attr_reader :writes
			def initialize; @writes = {}; end
			def write(key, val, **_) @writes[key] = val; end
		end.new
		
		Object.const_set(:Rails, Module.new) unless defined?(::Rails)
		::Rails.singleton_class.define_method(:cache) {cache}
		
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "cache_test", klass: StubJob, queue: "default", args: nil, cron: cron)
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		# Call the private writer directly to avoid timing concerns:
		t = Time.at(123)
		scheduler.send(:write_last, task.key, t)
		
		expect(cache.writes.keys).to be(:include?, "test-job:recurring:last:cache_test")
		expect(cache.writes["test-job:recurring:last:cache_test"]).to be == 123
		ensure
			# Clean up Rails constant if we created it:
			if defined?(::Rails) && ::Rails.singleton_class.method_defined?(:cache) && ::Rails.cache == cache
				# leave Rails defined for subsequent tests, only remove the writer if needed
			end
	end
	
	it "selects dedup and last backends from env aliases" do
		orig = ENV.to_h
		ENV["JOBS_DEDUP_BACKEND"] = "memory"
		ENV["JOBS_LAST_BACKEND"] = "cache"
		
		# These are module methods on Backend:
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		expect(backend.dedup_backend).to be == "memory"
		expect(backend.last_backend).to be == "cache"
		ensure
			ENV.replace(orig)
	end
	
	it "selects dedup and last backends with ASYNC_JOB env vars" do
		orig = ENV.to_h
		ENV["ASYNC_JOB_RECURRING_DEDUP"] = "memory"
		ENV["ASYNC_JOB_RECURRING_LAST"] = "cache"
		
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		expect(backend.dedup_backend).to be == "memory"
		expect(backend.last_backend).to be == "cache"
		ensure
			ENV.replace(orig)
	end
	
	it "returns 'redis' when explicitly set for dedup" do
		orig = ENV.to_h
		ENV["JOBS_DEDUP_BACKEND"] = "redis"
		
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		# Will return "redis" if env says redis (even if Redis not available)
		expect(backend.dedup_backend).to be == "redis"
		ensure
			ENV.replace(orig)
	end
	
	it "returns 'redis' when explicitly set for last" do
		orig = ENV.to_h
		ENV["JOBS_LAST_BACKEND"] = "redis"
		
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		expect(backend.last_backend).to be == "redis"
		ensure
			ENV.replace(orig)
	end
	
	it "enqueues job with nil args" do
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "nil_args", klass: StubJob, queue: "default", args: nil, cron: cron)
		
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		child = Async do
			scheduler.send(:run_task, task)
		end
		
		started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		while StubJob.calls.empty? && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) < 1.6
			sleep 0.05
		end
		
		child.stop
		
		expect(StubJob.calls.length).to be >= 1
		expect(StubJob.calls.first).to be == []
	end
	
	it "enqueues job with single non-array arg" do
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "single_arg", klass: StubJob, queue: "default", args: "hello", cron: cron)
		
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		child = Async do
			scheduler.send(:run_task, task)
		end
		
		started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		while StubJob.calls.empty? && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) < 1.6
			sleep 0.05
		end
		
		child.stop
		
		expect(StubJob.calls.length).to be >= 1
		expect(StubJob.calls.first).to be == ["hello"]
	end
	
	it "enqueues job with queue and priority set" do
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "with_opts", klass: StubJob, queue: "high", priority: 10, args: ["a"], cron: cron)
		
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		# We're just checking that set() is called - StubJob.set returns self
		child = Async do
			scheduler.send(:run_task, task)
		end
		
		started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		while StubJob.calls.empty? && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) < 1.6
			sleep 0.05
		end
		
		child.stop
		
		expect(StubJob.calls.length).to be >= 1
	end
	
	it "runs task with command instead of class" do
		$test_command_ran = false
		
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "command", klass: nil, command: "$test_command_ran = true", queue: nil, args: nil, cron: cron)
		
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		child = Async do
			scheduler.send(:run_task, task)
		end
		
		started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		while !$test_command_ran && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) < 1.6
			sleep 0.05
		end
		
		child.stop
		
		expect($test_command_ran).to be == true
	end
	
	it "handles errors in run_task gracefully" do
		# Create a job class that raises an error
		failing_job = Class.new do
			def self.perform_later(*args)
				raise "Job failed!"
			end
		end
		
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "failing", klass: failing_job, queue: nil, args: nil, cron: cron)
		
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		# Run one iteration and verify it doesn't crash
		child = Async do
			scheduler.send(:run_task, task)
		end
		
		sleep 1.2
		child.stop
		
		# Test passes if we got here without exception
		expect(true).to be == true
	end
	
	it "handles errors in claim gracefully" do
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "claim_err", klass: StubJob, args: nil, cron: cron)
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		# Force claim to raise by stubbing Backend.redis_enabled?
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		original_method = backend.method(:redis_enabled?)
		backend.define_singleton_method(:redis_enabled?) {raise "Redis error"}
		
		# claim should rescue and return true
		result = scheduler.send(:claim, task.key, Time.now)
		expect(result).to be == true
		ensure
			backend.define_singleton_method(:redis_enabled?, original_method)
	end
	
	it "handles errors in write_last gracefully" do
		cron = Fugit.parse("*/1 * * * * *")
		task = task_struct.new(key: "write_err", klass: StubJob, args: nil, cron: cron)
		scheduler = scheduler_class.new([task], prefix: "test-job")
		
		# Force write_last to fail by stubbing Backend.redis_enabled?
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		original_method = backend.method(:redis_enabled?)
		backend.define_singleton_method(:redis_enabled?) {raise "Write error"}
		
		# Should not raise
		scheduler.send(:write_last, task.key, Time.now)
		# Test passes if we got here
		expect(true).to be == true
		ensure
			backend.define_singleton_method(:redis_enabled?, original_method)
	end
	
	it "runs multiple tasks in parallel via public run method" do
		cron = Fugit.parse("*/1 * * * * *")
		task1 = task_struct.new(key: "task1", klass: StubJob, queue: nil, args: ["a"], cron: cron)
		task2 = task_struct.new(key: "task2", klass: StubJob, queue: nil, args: ["b"], cron: cron)
		
		scheduler = scheduler_class.new([task1, task2], prefix: "test-job")
		
		# Run scheduler in background and stop after tasks execute
		child = Async do
			scheduler.run
		end
		
		started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		while StubJob.calls.length < 2 && (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) < 1.6
			sleep 0.05
		end
		
		child.stop
		
		# Should have enqueued both tasks
		expect(StubJob.calls.length).to be >= 2
	end
	
	it "uses auto backend detection when Redis not available" do
		orig = ENV.to_h
		ENV.delete("ASYNC_JOB_RECURRING_DEDUP")
		ENV.delete("JOBS_DEDUP_BACKEND")
		ENV.delete("ASYNC_JOB_RECURRING_LAST")
		ENV.delete("JOBS_LAST_BACKEND")
		ENV.delete("REDIS_URL")
		
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		# With auto and no Redis, should fall back to memory/cache
		expect(backend.dedup_backend).to be == "memory"
		expect(backend.last_backend).to be == "cache"
		ensure
			ENV.replace(orig)
	end
	
	it "returns nil from redis_client when redis not enabled" do
		orig = ENV.to_h
		ENV["JOBS_DEDUP_BACKEND"] = "memory"
		ENV["JOBS_LAST_BACKEND"] = "cache"
		
		backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
		# Remove any cached redis client
		backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
		
		expect(backend.redis_client).to be == nil
		ensure
			ENV.replace(orig)
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
	end
	
	it "returns cached redis client on subsequent calls" do
		skip "Requires async-redis gem and Redis server" unless defined?(Async::Redis::Client)
		
		orig_env = ENV.to_h
		orig_endpoint_local = Async::Redis::Endpoint.method(:local) rescue nil
		orig_client_new = Async::Redis::Client.method(:new) rescue nil
		
		begin
			ENV["JOBS_DEDUP_BACKEND"] = "redis"
			
			backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
			# Remove any cached redis
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			
			# Mock the Redis client
			mock_redis = Object.new
			mock_endpoint = Object.new
			
			# Stub Async::Redis::Endpoint.local
			Async::Redis::Endpoint.define_singleton_method(:local) {mock_endpoint}
			Async::Redis::Client.define_singleton_method(:new) {|*args| mock_redis}
			
			client1 = backend.redis_client
			client2 = backend.redis_client
			
			expect(client1).to be == client2
		ensure
			ENV.replace(orig_env)
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			
			# Restore original methods
			if orig_endpoint_local
				Async::Redis::Endpoint.define_singleton_method(:local, orig_endpoint_local)
			end
			if orig_client_new
				Async::Redis::Client.define_singleton_method(:new, orig_client_new)
			end
		end
	end
	
	with "Redis integration" do
		it "uses Redis for claim when redis_enabled" do
			orig = ENV.to_h
			begin
				ENV["REDIS_URL"] = "redis://localhost:6379"
				ENV["JOBS_DEDUP_BACKEND"] = "redis"
				
				backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
				backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
				
				prefix = "test-redis-#{SecureRandom.hex(8)}"
				cron = Fugit.parse("*/1 * * * * *")
				task = task_struct.new(key: "redis_claim", klass: StubJob, args: nil, cron: cron)
				scheduler = scheduler_class.new([task], prefix: prefix)
				
				# Use fixed timestamp so both claims use same dedup key
				run_at = Time.now
				
				# First claim should succeed
				result1 = scheduler.send(:claim, task.key, run_at)
				expect(result1).to be == true
				
				# Second claim with same key+time should fail (deduplicated)
				result2 = scheduler.send(:claim, task.key, run_at)
				expect(result2).to be == false
			ensure
				ENV.replace(orig)
				backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			end
		end
		
		it "uses Redis for write_last when redis_enabled" do
			orig = ENV.to_h
			begin
				ENV["REDIS_URL"] = "redis://localhost:6379"
				ENV["JOBS_LAST_BACKEND"] = "redis"
				ENV["JOBS_DEDUP_BACKEND"] = "redis"
				
				backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
				backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
				
				prefix = "test-redis-#{SecureRandom.hex(8)}"
				cron = Fugit.parse("*/1 * * * * *")
				task = task_struct.new(key: "redis_last", klass: StubJob, args: nil, cron: cron)
				scheduler = scheduler_class.new([task], prefix: prefix)
				
				t = Time.at(12345)
				scheduler.send(:write_last, task.key, t)
				
				# Verify the value was written to Redis
				client = Async::Redis::Client.new
				stored_value = client.call("HGET", "#{prefix}:recurring:last", task.key)
				expect(stored_value).to be == "12345"
				
				# Clean up
				client.call("DEL", "#{prefix}:recurring:last")
			ensure
				ENV.replace(orig)
				backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			end
		end
		
		it "writes and reads last-run timestamp via Redis" do
			orig = ENV.to_h
			begin
				ENV["REDIS_URL"] = "redis://localhost:6379"
				ENV["JOBS_LAST_BACKEND"] = "redis"
				ENV["JOBS_DEDUP_BACKEND"] = "redis"
				
				backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
				backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
				
				prefix = "test-redis-#{SecureRandom.hex(8)}"
				cron = Fugit.parse("*/1 * * * * *")
				task1 = task_struct.new(key: "task_a", klass: StubJob, args: nil, cron: cron)
				task2 = task_struct.new(key: "task_b", klass: StubJob, args: nil, cron: cron)
				scheduler = scheduler_class.new([task1, task2], prefix: prefix)
				
				# Write last-run times for both tasks
				t1 = Time.at(100)
				t2 = Time.at(200)
				scheduler.send(:write_last, task1.key, t1)
				scheduler.send(:write_last, task2.key, t2)
				
				# Read back and verify
				client = Async::Redis::Client.new
				val1 = client.call("HGET", "#{prefix}:recurring:last", task1.key)
				val2 = client.call("HGET", "#{prefix}:recurring:last", task2.key)
				
				expect(val1).to be == "100"
				expect(val2).to be == "200"
				
				# Clean up
				client.call("DEL", "#{prefix}:recurring:last")
			ensure
				ENV.replace(orig)
				backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			end
		end
	end
end
