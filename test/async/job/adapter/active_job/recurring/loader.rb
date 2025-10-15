# frozen_string_literal: true

# Released under the MIT License.

require "yaml"
require "tmpdir"

require "sus/fixtures/async/reactor_context"

require "async/job/adapter/active_job/recurring/loader"
require "async/job/adapter/active_job/recurring/task"

describe Async::Job::Adapter::ActiveJob::Recurring::Loader do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:root) {Dir.mktmpdir("recurring-spec")}
	
	after do
		FileUtils.remove_entry(root) if File.exist?(root)
	end
	
	it 'loads tasks from recurring.yml and normalizes "every N seconds"' do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base' # any constant to survive constantize
          queue: default
          schedule: every 5 seconds
				YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		task = tasks.first
		expect(task.key).to be == "example"
		expect(task.queue).to be == "default"
		# Cron with seconds field every 5s
		expect(task.cron.original).to be == "*/5 * * * * *"
	end
	
	it 'normalizes "every N minutes"' do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: every 10 minutes
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		expect(tasks.first.cron.original).to be == "0 */10 * * * *"
	end
	
	it 'normalizes "every N hours"' do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: every 2 hours
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		expect(tasks.first.cron.original).to be == "0 0 */2 * * *"
	end
	
	it "returns empty array when file does not exist" do
		tasks = subject.load(root: root, env: "test")
		expect(tasks).to be == []
	end
	
	it "returns empty array when env has no tasks" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      production:
        example:
          class: 'ActiveJob::Base'
          schedule: every 5 seconds
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks).to be == []
	end
	
	it "skips task without schedule" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks).to be == []
	end
	
	it "skips task with invalid schedule" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: 'not a valid cron'
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks).to be == []
	end
	
	it "skips task with unknown job class" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'NonExistentJobClass'
          schedule: every 5 seconds
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks).to be == []
	end
	
	it "loads task with command instead of class" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          command: 'puts "Hello"'
          schedule: every 5 seconds
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		task = tasks.first
		expect(task.command).to be == 'puts "Hello"'
		expect(task.klass).to be == nil
	end
	
	it "loads task with priority and queue" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: every 5 seconds
          queue: high_priority
          priority: 10
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		task = tasks.first
		expect(task.queue).to be == "high_priority"
		expect(task.priority).to be == 10
	end
	
	it "loads task with array args" do
		path = File.join(root, "config/recurring.yml")
		FileUtils.mkdir_p(File.dirname(path))
		File.write(path, <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: every 5 seconds
          args: [1, 2, 3]
		YAML
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		expect(tasks.first.args).to be == [1, 2, 3]
	end
	
	it "uses ASYNC_JOB_RECURRING_SCHEDULE env var for schedule path" do
		ENV["ASYNC_JOB_RECURRING_SCHEDULE"] = File.join(root, "custom.yml")
		FileUtils.mkdir_p(root)
		File.write(ENV["ASYNC_JOB_RECURRING_SCHEDULE"], <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: every 5 seconds
		YAML
		
		path = subject.schedule_path(root)
		expect(path).to be == File.join(root, "custom.yml")
		
		tasks = subject.load(root: root, env: "test")
		expect(tasks.size).to be == 1
		ensure
			ENV.delete("ASYNC_JOB_RECURRING_SCHEDULE")
	end
	
	it "uses SOLID_QUEUE_RECURRING_SCHEDULE env var for schedule path" do
		ENV["SOLID_QUEUE_RECURRING_SCHEDULE"] = File.join(root, "solid.yml")
		FileUtils.mkdir_p(root)
		File.write(ENV["SOLID_QUEUE_RECURRING_SCHEDULE"], <<~YAML)
      test:
        example:
          class: 'ActiveJob::Base'
          schedule: every 5 seconds
		YAML
		
		path = subject.schedule_path(root)
		expect(path).to be == File.join(root, "solid.yml")
		ensure
			ENV.delete("SOLID_QUEUE_RECURRING_SCHEDULE")
	end
end

