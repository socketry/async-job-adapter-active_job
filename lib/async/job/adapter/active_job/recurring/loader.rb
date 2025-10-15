# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025

require 'yaml'
require 'console'
require_relative 'task'

module Async
  module Job
    module Adapter
      module ActiveJob
        module Recurring
          module Loader
            module_function

            DEFAULT_PATH = 'config/recurring.yml'

            def schedule_path(root)
              ENV['ASYNC_JOB_RECURRING_SCHEDULE'] || ENV['SOLID_QUEUE_RECURRING_SCHEDULE'] || ENV['RECURRING_SCHEDULE_FILE'] || File.join(root, DEFAULT_PATH)
            end

            # Load tasks from recurring.yml scoped by env.
            # @return [Array<Task>]
            def load(root:, env:)
              path = schedule_path(root)
              unless File.exist?(path)
                Console.info(self, "Recurring schedule file not found.", path: path)
                return []
              end

              config = YAML.load_file(path) || {}
              map = config.fetch(env.to_s, {}) || {}
              if map.empty?
                Console.info(self, "Recurring schedule has no tasks for env.", path: path, env: env)
              end

              map.filter_map do |key, spec|
                schedule = spec['schedule']
                unless schedule
                  Console.warn(self, "Skipping recurring task without schedule.", key: key, path: path)
                  next
                end

                cron_string = Helper.normalize_schedule(schedule)
                cron = Helper.parse_cron(cron_string)
                unless cron
                  Console.warn(self, "Skipping task: unsupported schedule.", key: key, schedule: schedule, normalized: cron_string, path: path)
                  next
                end

                if spec['class']
                  klass = Helper.constantize(spec['class'])
                  unless klass
                    Console.warn(self, "Skipping task: unknown job class.", key: key, class: spec['class'], path: path)
                    next
                  end
                end

                Task.new(
                  key: key.to_s,
                  klass: klass,
                  command: spec['command'],
                  queue: spec['queue'],
                  priority: spec['priority'],
                  args: spec['args'],
                  cron: cron
                )
              end
            end
          end
        end
      end
    end
  end
end
