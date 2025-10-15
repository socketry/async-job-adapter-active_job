# frozen_string_literal: true

# Released under the MIT License.

require 'yaml'
require 'tmpdir'

require 'sus/fixtures/async/reactor_context'

require 'async/job/adapter/active_job/recurring/loader'
require 'async/job/adapter/active_job/recurring/task'

describe Async::Job::Adapter::ActiveJob::Recurring::Loader do
  include Sus::Fixtures::Async::ReactorContext

  let(:root) { Dir.mktmpdir('recurring-spec') }

  after do
    FileUtils.remove_entry(root) if File.exist?(root)
  end

  it 'loads tasks from recurring.yml and normalizes "every N seconds"' do
    path = File.join(root, 'config/recurring.yml')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base' # any constant to survive constantize
          queue: default
          schedule: every 5 seconds
    YAML

    tasks = subject.load(root: root, env: 'test')
    expect(tasks.size).to be == 1
    task = tasks.first
    expect(task.key).to be == 'example'
    expect(task.queue).to be == 'default'
    # Cron with seconds field every 5s
    expect(task.cron.original).to be == '*/5 * * * * *'
  end
end

