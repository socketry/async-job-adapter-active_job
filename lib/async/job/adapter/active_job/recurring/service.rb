# frozen_string_literal: true

# Released under the MIT License.

require 'async/service/generic'
require 'async'
require 'console'

require_relative 'loader'
require_relative 'scheduler'

module Async
  module Job
    module Adapter
      module ActiveJob
        module Recurring
          class Service < Async::Service::Generic
            def setup(container)
              container.run(name: self.name, count: 1) do |instance|
                root = ENV.fetch('RAILS_ROOT', Dir.pwd)
                require File.expand_path('config/environment', root)

                if skip?
                  Console.info(self, "Recurring scheduler disabled via env.")
                  instance.ready!
                  Async { sleep }.wait
                  next
                end

                schedule_file = Loader.schedule_path(root)
                tasks = Loader.load(root: root, env: ::Rails.env)
                if tasks.empty?
                  if File.exist?(schedule_file)
                    Console.info(self, "No valid recurring tasks after parsing schedule.", env: ::Rails.env, path: schedule_file)
                  else
                    Console.info(self, "No recurring tasks loaded (missing file).", env: ::Rails.env, path: schedule_file)
                  end
                  instance.ready!
                  Async { sleep }.wait
                else
                  Console.info(self, "Starting recurring scheduler.", tasks: tasks.size, env: ::Rails.env, path: schedule_file,
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

            private
            def skip?
              ENV['ASYNC_JOB_SKIP_RECURRING'] == 'true' || ENV['SOLID_QUEUE_SKIP_RECURRING'] == 'true' || ENV['JOBS_SKIP_RECURRING'] == 'true'
            end
          end
        end
      end
    end
  end
end
