# frozen_string_literal: true

# Released under the MIT License.

require "async/service/generic"
require "async"
require "console"

require_relative "loader"
require_relative "scheduler"

module Async
	module Job
		module Adapter
			module ActiveJob
				module Recurring
					# Service for running the recurring task scheduler.
					class Service < Async::Service::Generic
						# Setup the recurring scheduler service container.
						# This implementation is framework-agnostic. It optionally boots the
						# application if a boot file is specified or detected, but does not
						# require Rails.
						# @parameter container [Async::Container::Generic] The service container.
						def setup(container)
							container.run(name: self.name, count: 1) do |instance|
								root = ENV.fetch("RAILS_ROOT", Dir.pwd)
								# Determine environment without relying on Rails:
								env = ENV["ASYNC_JOB_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || ENV["APP_ENV"] || "development"
								
								# Optionally boot the application. Prefer explicit boot file via env,
								# otherwise auto-detect common Rails boot file if present:
								boot = ENV["ASYNC_JOB_BOOT"]
								boot ||= "config/environment" if File.exist?(File.expand_path("config/environment.rb", root))
								begin
									require File.expand_path(boot, root) if boot
								rescue LoadError => e
									Console.warn(self, "Failed to boot application; continuing without.", boot: boot, exception: e)
								end
								
								if skip?
									Console.info(self, "Recurring scheduler disabled via env.")
									instance.ready!
									Async {sleep}.wait
								else
									schedule_file = Loader.schedule_path(root)
									tasks = Loader.load(root: root, env: env)
									# Reconcile tasks so removed ones are cleaned up (like sidekiq-cron):
									begin
										Reconciler.reconcile(tasks, prefix: Scheduler::DEFAULT_PREFIX)
									rescue => e
										Console.warn(self, "Failed to reconcile recurring tasks.", exception: e)
									end
									if tasks.empty?
										if File.exist?(schedule_file)
											Console.info(self, "No valid recurring tasks after parsing schedule.", env: env, path: schedule_file)
										else
											Console.info(self, "No recurring tasks loaded (missing file).", env: env, path: schedule_file)
										end
										instance.ready!
										Async {sleep}.wait
									else
										Console.info(self, "Starting recurring scheduler.", tasks: tasks.size, env: env, path: schedule_file,
																					dedup: Recurring::Backend.dedup_backend, last: Recurring::Backend.last_backend, prefix: Recurring::Scheduler::DEFAULT_PREFIX)
										# Per-task banner with schedule label and optional queue/priority:
										tasks.each do |t|
											label = t.cron.respond_to?(:original) ? t.cron.original : t.cron.to_s
											Console.info(self, "[scheduler] task", key: t.key, schedule: label, queue: t.queue, priority: t.priority)
										end
										instance.ready!
										# Ensure we have an async task context for the scheduler loops:
										Async do
											Scheduler.new(tasks).run
										end.wait
									end
								end
							end
						end
						
												private
						def skip?
							ENV["ASYNC_JOB_SKIP_RECURRING"] == "true" || ENV["SOLID_QUEUE_SKIP_RECURRING"] == "true" || ENV["JOBS_SKIP_RECURRING"] == "true"
						end
					end
				end
			end
		end
	end
end
