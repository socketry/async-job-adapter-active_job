# Getting Started

This gem connects Rails' Active Job framework to `async-job`. It includes an in-process queue for simple applications and development, and it can use processors such as Redis when jobs need to run in separate worker processes.

## Installation

Add the adapter to your Rails application:

```shell
$ bundle add async-job-adapter-active_job
```

The gem requires Ruby 3.3 or later.

## Quick Start

Configure Active Job to use the adapter in `config/application.rb`:

```ruby
module MyApplication
	class Application < Rails::Application
		config.active_job.queue_adapter = :async_job
	end
end
```

Create an Active Job as usual:

```ruby
class GreetingJob < ApplicationJob
	queue_as :default

	def perform(name)
		Rails.logger.info("Hello, #{name}!")
	end
end
```

Enqueue it with `perform_later`:

```ruby
GreetingJob.perform_later("World")
```

That is enough for a working setup. The adapter provides a `default` queue backed by {ruby Async::Job::Processor::Inline}, so it does not need Redis or a separate worker.

The inline processor is intentionally simple: jobs remain in the application process and will not survive a restart. Inside an Async event loop, such as a Rails application served by Falcon, jobs can run concurrently in background tasks. Outside an Async event loop, `perform_later` waits for the job to finish before returning.

## Using Redis and a Separate Worker

Use a persistent processor when jobs must outlive the web process or run on separate machines. Redis support is provided by a separate gem:

```shell
$ bundle add async-job-processor-redis
```

Replace the built-in `default` queue definition in `config/initializers/async_job.rb`:

```ruby
require "async/job/processor/redis"

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis, prefix: "my-application:#{Rails.env}:default"
	end
end
```

The Redis processor connects to Redis on the local default endpoint unless you pass it another endpoint. Use an application-, environment-, and queue-specific prefix to keep unrelated jobs separate. See the `async-job-processor-redis` documentation for connection and processor options.

Start a worker from the root of the Rails application so it can load `config/environment.rb`:

```shell
$ RAILS_ENV=production bundle exec async-job-adapter-active_job-server
```

By default, the worker starts every defined queue. To start only selected queues, provide a comma-separated list of definition names:

```shell
$ ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES=default,critical bundle exec async-job-adapter-active_job-server
```

If the command is not run from the Rails application root, set `RAILS_ROOT` explicitly.

An inline queue is local to the process that enqueues the job. Starting a separate worker for an inline queue does not move those jobs into that worker; use a shared processor such as Redis for that arrangement.

## Defining Multiple Queues

Every queue name used by an Active Job must have a matching definition or alias. For example:

```ruby
require "async/job/processor/redis"

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis, prefix: "my-application:#{Rails.env}:default"
	end

	config.async_job.define_queue "critical" do
		dequeue Async::Job::Processor::Redis, prefix: "my-application:#{Rails.env}:critical"
	end

	config.async_job.alias_queue "default", "mailers"
end
```

Jobs can then select a queue using the standard Active Job API:

```ruby
class BillingJob < ApplicationJob
	queue_as :critical

	def perform(account_id)
		# ...
	end
end
```

Aliases route several Active Job queue names through one `async-job` queue definition. Worker selection through `ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES` uses definition names (`default` and `critical` above), not aliases (`mailers`).

## Opting In One Job at a Time

You do not need to replace the application's global adapter. To migrate incrementally, configure the adapter on an individual job:

```ruby
class GreetingJob < ApplicationJob
	self.queue_adapter = :async_job
	queue_as :default

	def perform(name)
		Rails.logger.info("Hello, #{name}!")
	end
end
```

Queue definitions are still configured through `config.async_job` in the same way.

## How It Fits Together

When `perform_later` is called, {ruby ActiveJob::QueueAdapters::AsyncJobAdapter} serializes the Active Job and sends it to the `async-job` queue selected by `queue_as`. The configured processor transports or schedules the payload. On the consumer side, {ruby Async::Job::Adapter::ActiveJob::Executor} deserializes it and invokes Active Job.

Queue definitions use `async-job`'s pipeline builder. The processor is written as `dequeue` because it wraps the consumer side of that pipeline; it still provides the client used by the Rails process to enqueue jobs. The Active Job executor is appended automatically and should not be added to the definition.
