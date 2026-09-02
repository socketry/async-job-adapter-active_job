# Getting Started

This guide explains how to use `async-job-adapter-active_job` to run Rails Active Job workloads with inline or Redis-backed queues.

## Installation

Add the adapter to your Rails application:

```shell
$ bundle add async-job-adapter-active_job
```

The gem requires Ruby 3.3 or later.

## Core Concepts

The adapter connects Active Job's standard API to an `async-job` processing pipeline:

- ruby:`ActiveJob::QueueAdapters::AsyncJobAdapter` receives jobs from `perform_later` and dispatches their serialized payloads.
- A queue definition maps an Active Job queue name to an `async-job` processor.
- The processor determines where jobs wait and run. The built-in inline processor keeps work in the application process, while processors such as Redis support separate workers.
- ruby:`Async::Job::Adapter::ActiveJob::Executor` deserializes queued payloads and invokes Active Job.

Active Job remains responsible for arguments, callbacks, retries, and error handling. This gem supplies the queue adapter and worker integration.

## Quick Start

The built-in inline queue is the quickest way to get started because it does not require Redis or a separate worker. It is useful during development and for non-critical work that can remain in the application process.

Configure Active Job to use the adapter in `config/application.rb`:

```ruby
module MyApplication
	class Application < Rails::Application
		config.active_job.queue_adapter = :async_job
	end
end
```

Create an Active Job as usual. Define retry and discard behavior on the job so expected failures are handled explicitly:

```ruby
class SearchIndexRefreshJob < ApplicationJob
	queue_as :default
	retry_on SearchIndex::Unavailable, wait: 5.seconds, attempts: 3
	discard_on ActiveRecord::RecordNotFound

	def perform(product_id)
		Product.find(product_id).refresh_search_index!
	end
end
```

Enqueue it with `perform_later`:

```ruby
SearchIndexRefreshJob.perform_later(product.id)
```

Scheduled jobs use the standard Active Job API too:

```ruby
SearchIndexRefreshJob.set(wait: 5.minutes).perform_later(product.id)
```

That is enough for a working setup. The adapter provides a `default` queue backed by ruby:`Async::Job::Processor::Inline`.

The inline processor is intentionally simple: jobs remain in the application process and will not survive a restart. Inside an Async event loop, such as a Rails application served by Falcon, jobs can run concurrently in background tasks. Outside an Async event loop, `perform_later` waits for the job to finish before returning.

## Using Redis and a Separate Worker

Web processes are frequently restarted or scaled independently, so important jobs need a shared queue. Use a Redis-backed queue when jobs must:

- Survive a web process restart.
- Run outside the request-serving process.
- Be consumed by workers on separate machines.

Redis support is provided by a separate gem:

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

An inline queue is local to the process that enqueues the job. Starting a separate worker for an inline queue does not move those jobs into that worker; use a shared processor such as Redis for that arrangement. Conversely, keep the inline queue when process restarts and separate worker capacity are not concerns.

## Defining Multiple Queues

Multiple queue definitions let you isolate latency-sensitive jobs from slower bulk work and assign them to different worker groups. Every queue name used by an Active Job must have a matching definition or alias.

For example, define a dedicated queue for critical billing work while routing Rails' `mailers` queue through the default processor:

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
class PaymentCaptureJob < ApplicationJob
	queue_as :critical

	def perform(payment_id)
		Payment.find(payment_id).capture!
	end
end
```

Aliases route several Active Job queue names through one `async-job` queue definition. Worker selection through `ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES` uses definition names (`default` and `critical` above), not aliases (`mailers`).

Prefer an alias when jobs only need another Active Job queue name. Create a separate definition, Redis prefix, and worker group when the workload needs genuine isolation.

## Opting In One Job at a Time

You do not need to replace the application's global adapter. To migrate incrementally, configure the adapter on an individual job:

```ruby
class SearchIndexRefreshJob < ApplicationJob
	self.queue_adapter = :async_job
	queue_as :default
	retry_on SearchIndex::Unavailable, wait: 5.seconds, attempts: 3
	discard_on ActiveRecord::RecordNotFound

	def perform(product_id)
		Product.find(product_id).refresh_search_index!
	end
end
```

Queue definitions are still configured through `config.async_job` in the same way.

## How It Fits Together

When `perform_later` is called, ruby:`ActiveJob::QueueAdapters::AsyncJobAdapter` serializes the Active Job and sends it to the `async-job` queue selected by `queue_as`. The configured processor transports or schedules the payload. On the consumer side, ruby:`Async::Job::Adapter::ActiveJob::Executor` deserializes it and invokes Active Job.

Queue definitions use `async-job`'s pipeline builder. The processor is written as `dequeue` because it wraps the consumer side of that pipeline; it still provides the client used by the Rails process to enqueue jobs. The Active Job executor is appended automatically and should not be added to the definition.

## Troubleshooting

### A Queue Name Raises `KeyError`

The name selected by `queue_as` does not have a matching definition or alias. Add it with `config.async_job.define_queue` or route it using `config.async_job.alias_queue`.

### `perform_later` Waits for the Job

The inline processor runs synchronously when there is no active Async event loop. Run Rails with an Async-based server such as Falcon for in-process concurrency, or use Redis and a separate worker for process isolation.

### Jobs Do Not Reach the Worker

Confirm that both the Rails process and worker load the same queue definition, Redis endpoint, prefix, and Rails environment. An inline definition cannot send work to another process.

### The Worker Cannot Load Rails

Run `async-job-adapter-active_job-server` from the Rails application root, or set `RAILS_ROOT` to the directory containing `config/environment.rb`.

### A Selected Queue Does Not Start

`ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES` accepts comma-separated definition names, not aliases. Avoid spaces around the names.
