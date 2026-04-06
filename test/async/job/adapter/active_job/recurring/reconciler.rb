# frozen_string_literal: true

# Released under the MIT License.

require "sus/fixtures/async/reactor_context"
require "sus/fixtures/console"

require "fugit"

require "async/job/adapter/active_job/recurring/task"
require "async/job/adapter/active_job/recurring/scheduler"

describe Async::Job::Adapter::ActiveJob::Recurring::Reconciler do
	include Sus::Fixtures::Async::ReactorContext
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:task_struct) {Async::Job::Adapter::ActiveJob::Recurring::Task}
	let(:reconciler) {Async::Job::Adapter::ActiveJob::Recurring::Reconciler}
	let(:backend) {Async::Job::Adapter::ActiveJob::Recurring::Backend}
	
	def with_redis_enabled
		orig = ENV.to_h
		begin
			ENV["REDIS_URL"] = "redis://localhost:6379"
			ENV["JOBS_DEDUP_BACKEND"] = "redis"
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			yield
		ensure
			ENV.replace(orig)
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
		end
	end
	
	with "Redis integration" do
		it "removes orphaned tasks from Redis when they are removed from schedule" do
			with_redis_enabled do
				prefix = "test-reconcile-#{rand(100000)}"
				redis = backend.redis_client
				
				# Create two tasks
				cron = Fugit.parse("*/1 * * * * *")
				task1 = task_struct.new(key: "task_keep", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
				task2 = task_struct.new(key: "task_remove", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
				
				# Simulate that both tasks existed previously in Redis
				set_key = "#{prefix}:recurring:tasks"
				redis.call("SADD", set_key, "task_keep", "task_remove")
				
				# Add some dedup keys for task_remove
				redis.call("SET", "#{prefix}:recurring:exec:task_remove:12345", "value1")
				redis.call("SET", "#{prefix}:recurring:exec:task_remove:67890", "value2")
				
				# Add last-run record for task_remove
				last_key = "#{prefix}:recurring:last"
				redis.call("HSET", last_key, "task_remove", "12345")
				
				# Now reconcile with only task1 (task2 was removed from schedule)
				reconciler.reconcile([task1], prefix: prefix)
				
				# Verify task_remove was cleaned up
				members = redis.call("SMEMBERS", set_key)
				expect(members).to be == ["task_keep"]
				
				# Verify dedup keys were deleted
				keys = redis.call("KEYS", "#{prefix}:recurring:exec:task_remove:*")
				expect(keys).to be == []
				
				# Verify last-run record was deleted
				last_val = redis.call("HGET", last_key, "task_remove")
				expect(last_val).to be == nil
				
				# Cleanup
				redis.call("DEL", set_key, last_key)
			end
		end
		
		it "adds new tasks to Redis when they are added to schedule" do
			with_redis_enabled do
				prefix = "test-reconcile-add-#{rand(100000)}"
				redis = backend.redis_client
				
				# Create two tasks
				cron = Fugit.parse("*/1 * * * * *")
				task1 = task_struct.new(key: "task_existing", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
				task2 = task_struct.new(key: "task_new", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
				
				# Simulate that only task1 existed previously in Redis
				set_key = "#{prefix}:recurring:tasks"
				redis.call("SADD", set_key, "task_existing")
				
				# Now reconcile with both tasks (task2 is new)
				reconciler.reconcile([task1, task2], prefix: prefix)
				
				# Verify both tasks are now in the set
				members = redis.call("SMEMBERS", set_key).sort
				expect(members).to be == ["task_existing", "task_new"]
				
				# Cleanup
				redis.call("DEL", set_key)
			end
		end
		
		it "handles empty removed and added lists gracefully" do
			with_redis_enabled do
				prefix = "test-reconcile-noop-#{rand(100000)}"
				redis = backend.redis_client
				
				cron = Fugit.parse("*/1 * * * * *")
				task1 = task_struct.new(key: "task1", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
				
				set_key = "#{prefix}:recurring:tasks"
				redis.call("SADD", set_key, "task1")
				
				# Reconcile with same task (no changes)
				reconciler.reconcile([task1], prefix: prefix)
				
				# Should still have the task
				members = redis.call("SMEMBERS", set_key)
				expect(members).to be == ["task1"]
				
				# Cleanup
				redis.call("DEL", set_key)
			end
		end
		
		it "scans and deletes keys matching a pattern" do
			with_redis_enabled do
				prefix = "test-scan-#{rand(100000)}"
				redis = backend.redis_client
				
				# Create multiple keys matching the pattern
				redis.call("SET", "#{prefix}:recurring:exec:task1:111", "v1")
				redis.call("SET", "#{prefix}:recurring:exec:task1:222", "v2")
				redis.call("SET", "#{prefix}:recurring:exec:task1:333", "v3")
				# Create a key that doesn't match
				redis.call("SET", "#{prefix}:recurring:exec:task2:444", "v4")
				
				# Scan and delete task1 keys
				pattern = "#{prefix}:recurring:exec:task1:*"
				reconciler.scan_and_delete(redis, pattern)
				
				# Verify task1 keys are gone
				keys = redis.call("KEYS", "#{prefix}:recurring:exec:task1:*")
				expect(keys).to be == []
				
				# Verify task2 key still exists
				keys = redis.call("KEYS", "#{prefix}:recurring:exec:task2:*")
				expect(keys.length).to be == 1
				
				# Cleanup
				redis.call("DEL", "#{prefix}:recurring:exec:task2:444")
			end
		end
	end
	
	it "returns early when Redis is not enabled" do
		orig = ENV.to_h
		begin
			ENV.delete("REDIS_URL")
			ENV["JOBS_DEDUP_BACKEND"] = "memory"
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
			
			cron = Fugit.parse("*/1 * * * * *")
			task1 = task_struct.new(key: "task1", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
			
			# Should return early without error
			reconciler.reconcile([task1], prefix: "test")
			
			# Test passes if we got here
			expect(true).to be == true
		ensure
			ENV.replace(orig)
			backend.remove_instance_variable(:@redis) if backend.instance_variable_defined?(:@redis)
		end
	end
	
	with "Redis integration" do
		it "logs warning when reconcile encounters Redis error" do
			with_redis_enabled do
				prefix = "test-reconcile-error-#{rand(100000)}"
				cron = Fugit.parse("*/1 * * * * *")
				task1 = task_struct.new(key: "task1", klass: nil, command: nil, queue: "default", priority: 0, args: nil, cron: cron)
				
				# Stub redis_client to return a mock that raises on SMEMBERS
				redis_orig = backend.method(:redis_client)
				failing_redis = Object.new
				def failing_redis.call(*args)
					raise "Redis connection failed!"
				end
				
				backend.define_singleton_method(:redis_client) {failing_redis}
				
				# Should rescue and log warning
				reconciler.reconcile([task1], prefix: prefix)
				
				# Check that warning was logged
				expect_console.to have_logged(message: be(:include?, "[recurring] reconcile failed"))
				
				# Test passes if we got here without exception
				expect(true).to be == true
			ensure
				backend.define_singleton_method(:redis_client, redis_orig) if redis_orig
			end
		end
	end
end
