# frozen_string_literal: true

# Released under the MIT License.

require 'sus/fixtures/async/reactor_context'
require 'sus/fixtures/console'

require 'fugit'

require 'async/job/adapter/active_job/recurring/task'
require 'async/job/adapter/active_job/recurring/scheduler'

describe Async::Job::Adapter::ActiveJob::Recurring::Scheduler do
  include Sus::Fixtures::Async::ReactorContext
  include Sus::Fixtures::Console::CapturedLogger

  let(:task_struct) { Async::Job::Adapter::ActiveJob::Recurring::Task }
  let(:scheduler_class) { Async::Job::Adapter::ActiveJob::Recurring::Scheduler }

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

  before { StubJob.reset! }

  it 'enqueues a job on schedule (memory dedup, no Redis)' do
    # Every 1 second.
    cron = Fugit.parse('*/1 * * * * *')
    task = task_struct.new(key: 'test', klass: StubJob, command: nil, queue: 'default', priority: 0, args: ['a'], cron: cron)

    scheduler = scheduler_class.new([task], prefix: 'test-job')

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
    expect(StubJob.calls.first).to be == ['a']
  end

  it 'writes last-run to Rails.cache when Redis is not enabled' do
    # Install a minimal Rails.cache stub.
    cache = Class.new do
      attr_reader :writes
      def initialize; @writes = {}; end
      def write(key, val, **_) @writes[key] = val; end
    end.new

    Object.const_set(:Rails, Module.new) unless defined?(::Rails)
    ::Rails.singleton_class.define_method(:cache) { cache }

    cron = Fugit.parse('*/1 * * * * *')
    task = task_struct.new(key: 'cache_test', klass: StubJob, queue: 'default', args: nil, cron: cron)
    scheduler = scheduler_class.new([task], prefix: 'test-job')

    # Call the private writer directly to avoid timing concerns:
    t = Time.at(123)
    scheduler.send(:write_last, task.key, t)

    expect(cache.writes.keys).to be(:include?, 'test-job:recurring:last:cache_test')
    expect(cache.writes['test-job:recurring:last:cache_test']).to be == 123
  ensure
    # Clean up Rails constant if we created it:
    if defined?(::Rails) && ::Rails.singleton_class.method_defined?(:cache) && ::Rails.cache == cache
      # leave Rails defined for subsequent tests, only remove the writer if needed
    end
  end

  it 'selects dedup and last backends from env aliases' do
    orig = ENV.to_h
    ENV['JOBS_DEDUP_BACKEND'] = 'memory'
    ENV['JOBS_LAST_BACKEND'] = 'cache'

    # These are module methods on Backend:
    backend = Async::Job::Adapter::ActiveJob::Recurring::Backend
    expect(backend.dedup_backend).to be == 'memory'
    expect(backend.last_backend).to be == 'cache'
  ensure
    ENV.replace(orig)
  end
end

