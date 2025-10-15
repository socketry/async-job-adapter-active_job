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
					module Backend
						module_function
						
						def redis_enabled?
							backend = ENV["ASYNC_JOB_RECURRING_DEDUP"] || ENV["JOBS_DEDUP_BACKEND"] || "auto"
							last = ENV["ASYNC_JOB_RECURRING_LAST"] || ENV["JOBS_LAST_BACKEND"] || "auto"
							wants_redis = [backend, last].any? {|v| v == "redis"}
							auto_redis = ([backend, last].include?("auto") && ENV.key?("REDIS_URL"))
							(wants_redis || auto_redis) && defined?(Async::Redis::Client)
						end
						
						def redis_client
							return @redis if defined?(@redis) && @redis
							return nil unless redis_enabled?
							
							endpoint = ENV["REDIS_URL"] ? Async::Redis::Endpoint.parse(ENV["REDIS_URL"]) : Async::Redis::Endpoint.local
							@redis = Async::Redis::Client.new(endpoint)
						end
						
						def dedup_backend
							v = ENV["ASYNC_JOB_RECURRING_DEDUP"] || ENV["JOBS_DEDUP_BACKEND"] || "auto"
							return "redis" if v == "redis"
							return "memory" if v == "memory"
							redis_enabled? ? "redis" : "memory"
						end
						
						def last_backend
							v = ENV["ASYNC_JOB_RECURRING_LAST"] || ENV["JOBS_LAST_BACKEND"] || "auto"
							return "redis" if v == "redis"
							return "cache" if v == "cache"
							redis_enabled? ? "redis" : "cache"
						end
					end
					
					class Scheduler
						DEFAULT_DEDUP_TTL = Integer(ENV["ASYNC_JOB_RECURRING_DEDUP_TTL"] || ENV["JOBS_SCHEDULER_DEDUP_TTL"] || "600")
						DEFAULT_PREFIX = ENV["ASYNC_JOB_REDIS_PREFIX"] || ENV["JOBS_REDIS_PREFIX"] || "async-job"
						
						def initialize(tasks, prefix: DEFAULT_PREFIX)
							@tasks = tasks
							@prefix = prefix
						end
						
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
								now = Time.now
								next_eo = task.cron.next_time(now)
								delay = next_eo.to_f - now.to_f
								Async::Task.current.sleep(delay) if delay > 0
								
								run_at = Time.at(next_eo.to_i)
								begin
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
