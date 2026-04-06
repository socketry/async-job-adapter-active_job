# frozen_string_literal: true

# Released under the MIT License.

require "console"
require "socket"

begin
	require "async/redis/client"
rescue LoadError
	# Optional; only used if REDIS_URL is present or backend=redis.
end

module Async
	module Job
		module Adapter
			module ActiveJob
				module Recurring
					# Reconciles configured recurring tasks with any previously
					# persisted set, removing keys for tasks that were removed
					# from the schedule (sidekiq-cron style). This does NOT
					# purge already-enqueued jobs from queues.
					module Reconciler
						module_function
						
						# Reconcile configured tasks with persisted Redis state, removing keys for deleted tasks.
						# Cleans up deduplication locks, last-run records, and task set entries for tasks
						# that were removed from the schedule configuration.
						# @parameter tasks [Array<Task>] The current set of recurring tasks to reconcile.
						# @parameter prefix [String] The Redis key prefix for recurring task data.
						def reconcile(tasks, prefix: Scheduler::DEFAULT_PREFIX)
							return unless Backend.redis_enabled?
							redis = Backend.redis_client
							set_key = "#{prefix}:recurring:tasks"
							last_key = "#{prefix}:recurring:last"
							
							current = Array(tasks).map(&:key)
							existing = redis.call("SMEMBERS", set_key) || []
							removed  = existing - current
							added    = current - existing
							
							removed.each do |key|
								# Delete dedup locks for historical executions of this task
								pattern = "#{prefix}:recurring:exec:#{key}:*"
								scan_and_delete(redis, pattern)
								# Drop last-run record for this task
								redis.call("HDEL", last_key, key)
								# Remove from tasks set
								redis.call("SREM", set_key, key)
								Console.info(self, "[recurring] removed task", key: key)
							end
							
							redis.call("SADD", set_key, *added) unless added.empty?
							Console.info(self, "[recurring] reconcile", kept: (current - added), removed: removed, added: added) unless (removed.empty? && added.empty?)
						rescue => e
							Console.warn(self, "[recurring] reconcile failed", exception: e)
						end
						
						# Scan Redis for keys matching a pattern and delete them in batches.
						# Uses Redis SCAN to safely iterate through keys without blocking.
						# @parameter redis [Async::Redis::Client] The Redis client connection.
						# @parameter pattern [String] The Redis key pattern to match (e.g., "prefix:*").
						def scan_and_delete(redis, pattern)
							cursor = "0"
							begin
								cursor, batch = redis.call("SCAN", cursor, "MATCH", pattern, "COUNT", 200)
								slice = Array(batch)
								redis.call("DEL", *slice) unless slice.empty?
							end while cursor != "0"
						end
					end
					
					# Backend configuration for deduplication and last-run tracking.
					module Backend
						module_function
						
						# Check if Redis backend is enabled based on environment configuration.
						# @returns [Boolean] True if Redis is enabled and available.
						def redis_enabled?
							backend = ENV["ASYNC_JOB_RECURRING_DEDUP"] || ENV["JOBS_DEDUP_BACKEND"] || "auto"
							last = ENV["ASYNC_JOB_RECURRING_LAST"] || ENV["JOBS_LAST_BACKEND"] || "auto"
							wants_redis = [backend, last].any? {|v| v == "redis"}
							auto_redis = ([backend, last].include?("auto") && ENV.key?("REDIS_URL"))
							(wants_redis || auto_redis) && defined?(Async::Redis::Client)
						end
						
						# Get or create a Redis client connection.
						# @returns [Async::Redis::Client, nil] The Redis client or nil if not enabled.
						def redis_client
							return @redis if defined?(@redis) && @redis
							return nil unless redis_enabled?
							
							endpoint = ENV["REDIS_URL"] ? Async::Redis::Endpoint.parse(ENV["REDIS_URL"]) : Async::Redis::Endpoint.local
							@redis = Async::Redis::Client.new(endpoint)
						end
						
						# Determine which backend to use for deduplication.
						# @returns [String] Either "redis" or "memory".
						def dedup_backend
							v = ENV["ASYNC_JOB_RECURRING_DEDUP"] || ENV["JOBS_DEDUP_BACKEND"] || "auto"
							return "redis" if v == "redis"
							return "memory" if v == "memory"
							redis_enabled? ? "redis" : "memory"
						end
						
						# Determine which backend to use for last-run tracking.
						# @returns [String] Either "redis" or "cache".
						def last_backend
							v = ENV["ASYNC_JOB_RECURRING_LAST"] || ENV["JOBS_LAST_BACKEND"] || "auto"
							return "redis" if v == "redis"
							return "cache" if v == "cache"
							redis_enabled? ? "redis" : "cache"
						end
					end
					
					# Schedules and enqueues recurring tasks based on cron expressions.
					class Scheduler
						DEFAULT_DEDUP_TTL = Integer(ENV["ASYNC_JOB_RECURRING_DEDUP_TTL"] || ENV["JOBS_SCHEDULER_DEDUP_TTL"] || "600")
						DEFAULT_PREFIX = ENV["ASYNC_JOB_REDIS_PREFIX"] || ENV["JOBS_REDIS_PREFIX"] || "async-job"
						
						# Initialize the scheduler with a list of tasks.
						# @parameter tasks [Array<Task>] The recurring tasks to schedule.
						# @parameter prefix [String] The Redis key prefix.
						def initialize(tasks, prefix: DEFAULT_PREFIX)
							@tasks = tasks
							@prefix = prefix
						end
						
						# Start the scheduler and run all recurring tasks in parallel.
						def run
							barrier = Async::Barrier.new
							@tasks.each do |task|
								barrier.async {run_task(task)}
							end
							barrier.wait
						end
						
														private
						def run_task(task)
							loop do
								begin
									now = Time.now
									next_eo = task.cron.next_time(now)
									delay = next_eo.to_f - now.to_f
									Async::Task.current.sleep(delay) if delay > 0
									
									run_at = Time.at(next_eo.to_i)
									next unless claim(task.key, run_at)
									
									if task.klass
										set_opts = {}
										set_opts[:queue] = task.queue if task.queue
										set_opts[:priority] = task.priority if task.priority
										job = set_opts.empty? ? task.klass : task.klass.set(**set_opts)
										args = task.args
										if args.nil?
											job.perform_later
										elsif args.is_a?(Array)
											job.perform_later(*args)
										else
											job.perform_later(args)
										end
									elsif task.command
										eval(task.command, TOPLEVEL_BINDING)
									end
									
									write_last(task.key, Time.now)
									Console.info(self, "Enqueued recurring task.", key: task.key)
								rescue => e
									Console.warn(self, "Recurring task failed!", key: task.key, exception: e)
									# Sleep briefly before retrying to avoid tight error loop
									Async::Task.current.sleep(5)
								end
							end
						end
						
						def claim(key, run_at)
							if Backend.redis_enabled?
								redis = Backend.redis_client
								dedup_key = "#{@prefix}:recurring:exec:#{key}:#{run_at.to_i}"
								value = "#{Socket.gethostname}-#{Process.pid}"
								result = redis.call("SET", dedup_key, value, "NX", "EX", DEFAULT_DEDUP_TTL)
								return result == "OK"
							else
								@mem ||= {}
								mk = [key, run_at.to_i].join(":")
								return false if @mem[mk]
								@mem[mk] = true
								return true
							end
														rescue => e
															Console.warn(self, "Dedup claim failed; proceeding.", key: key, exception: e)
															true
						end
						
						def write_last(key, t)
							if Backend.redis_enabled?
								Backend.redis_client.call("HSET", "#{@prefix}:recurring:last", key, t.to_i)
							else
								if defined?(::Rails) && ::Rails.respond_to?(:cache) && ::Rails.cache
									::Rails.cache.write("#{@prefix}:recurring:last:#{key}", t.to_i, expires_in: 1.hour)
								end
							end
														rescue => e
															Console.warn(self, "Failed to write last run.", key: key, exception: e)
						end
					end
				end
			end
		end
	end
end
