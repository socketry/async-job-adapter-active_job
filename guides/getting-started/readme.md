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

## Next Steps

- [Production Deployment](../production-deployment/index) explains how to move jobs into a shared Redis queue and run separate worker processes.
- [Queue Configuration](../queue-configuration/index) explains queue definitions, aliases, multiple queues, and per-job adoption.
