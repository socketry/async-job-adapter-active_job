# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require 'fugit'

module Async
  module Job
    module Adapter
      module ActiveJob
        module Recurring
          # Represents a single recurring task loaded from config/recurring.yml.
          Task = Struct.new(:key, :klass, :command, :queue, :priority, :args, :cron, keyword_init: true)

          module Helper
            module_function

            # Normalize simple natural schedules to a cron string that Fugit::Cron understands.
            def normalize_schedule(spec)
              s = spec.to_s.strip
              return s if s.empty?

              if (m = s.match(/\Aevery\s+(\d+)\s*seconds?\z/i))
                "*/#{Integer(m[1])} * * * * *"
              elsif (m = s.match(/\Aevery\s+(\d+)\s*minutes?\z/i))
                "0 */#{Integer(m[1])} * * * *"
              elsif (m = s.match(/\Aevery\s+(\d+)\s*hours?\z/i))
                "0 0 */#{Integer(m[1])} * * *"
              else
                s
              end
            end

            def parse_cron(s)
              cron = Fugit.parse(s)
              cron.is_a?(Fugit::Cron) ? cron : nil
            end

            def constantize(name)
              name.to_s.split('::').inject(Object) { |m, part| m.const_get(part) }
            rescue NameError
              nil
            end
          end
        end
      end
    end
  end
end

