# Queue Configuration

This guide explains how to configure `async-job` queue definitions, route Active Jobs, and adopt the adapter incrementally.

## Overview

Active Job assigns every job a queue name. The adapter must map that name to an `async-job` queue definition, which specifies the processor responsible for storing and running the job.

The adapter includes a `default` definition backed by ruby:`Async::Job::Processor::Inline`. Define additional queues when you need:

- A shared processor such as Redis instead of in-process execution.
- Separate capacity for latency-sensitive and bulk workloads.
- Several Active Job queue names routed through one processor.

Every name selected by `queue_as` must have a matching definition or alias.

## Defining a Queue

Queue definitions belong in `config/initializers/async_job.rb`. The examples below use the Redis processor so independently operated queues have shared storage:

```shell
$ bundle add async-job-processor-redis
```

This definition replaces the built-in inline `default` queue:

```ruby
require "async/job/processor/redis"

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis
	end
end
```

Processors can accept positional and keyword arguments after the processor class.

## Redis Endpoints

Without an explicit `endpoint`, the Redis processor connects to `redis://localhost:6379`. Pass an ruby:`Async::Redis::Endpoint` when Redis runs on another host, requires credentials, uses a different database, or accepts TLS connections:

```ruby
redis_endpoint = Async::Redis::Endpoint.parse(ENV.fetch("REDIS_URL"))

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis, endpoint: redis_endpoint
	end
end
```

`REDIS_URL` may use either the `redis://` or `rediss://` scheme and can include credentials, a port, and a database number, for example `redis://username:password@redis.example.com:6379/1`. Keep credentials in the environment rather than writing them into the initializer.

The bundled worker loads the Rails environment, so Rails and worker processes use the same queue definition. Ensure `REDIS_URL` is present and identical in both process environments.

## Redis Prefixes

Without an explicit `prefix`, every Redis processor uses `async-job`. Queue definition names do not alter that default, so two definitions using the same Redis endpoint and prefix operate on the same underlying queue.

For each independently processed queue, the prefix must be:

- Distinct from other queues using the same Redis endpoint.
- Identical in Rails and worker processes.
- Stable across deployments so existing jobs remain reachable.

Include an application or environment namespace only when those workloads share a Redis endpoint.

## Defining Multiple Queues

Multiple definitions allow independent worker groups to process different workloads. For example, payment capture can use a dedicated queue while ordinary work remains on `default`:

```ruby
require "async/job/processor/redis"

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis, prefix: "async-job:default"
	end
	
	config.async_job.define_queue "critical" do
		dequeue Async::Job::Processor::Redis, prefix: "async-job:critical"
	end
end
```

Select the definition using the standard Active Job API:

```ruby
class PaymentCaptureJob < ApplicationJob
	queue_as :critical
	retry_on PaymentGateway::Unavailable, wait: 5.seconds, attempts: 5
	discard_on ActiveRecord::RecordNotFound
	
	def perform(payment_id)
		Payment.find(payment_id).capture!
	end
end
```

Create separate definitions only when workloads need distinct storage, capacity, or operational controls. A single definition is simpler when those differences do not matter.

## Aliasing Queue Names

Aliases route several Active Job queue names through one queue definition. This is useful for framework-defined names such as `mailers` when they do not need independent worker capacity:

```ruby
Rails.application.configure do
	config.async_job.alias_queue "default", "mailers", "low_priority"
end
```

Jobs assigned to `mailers` or `low_priority` are submitted through the `default` definition. Aliases do not create queues and are not valid values for `ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES`; worker selection uses definition names.

## Opting In One Job at a Time

Applications can adopt the adapter without replacing their global Active Job backend. Set `queue_adapter` on an individual job and leave other jobs unchanged:

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

The selected queue must still have a definition or alias in `config.async_job`.

## Understanding the Pipeline

When `perform_later` is called, ruby:`ActiveJob::QueueAdapters::AsyncJobAdapter` serializes the Active Job and sends it to the definition selected by `queue_as`. The configured processor transports or schedules the payload. On the consumer side, ruby:`Async::Job::Adapter::ActiveJob::Executor` deserializes it and invokes Active Job.

Definitions use `async-job`'s pipeline builder. The processor is written as `dequeue` because it wraps the consumer side of the pipeline; it still supplies the client used by Rails to enqueue jobs. The Active Job executor is appended automatically and should not be added to the definition.
