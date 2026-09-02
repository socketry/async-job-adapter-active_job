# Production Deployment

This guide explains how to deploy `async-job-adapter-active_job` with Redis-backed queues and separate worker processes.

## Overview

The built-in inline processor keeps jobs inside the Rails process. That is convenient for development, but jobs cannot survive a process restart or be consumed by another machine.

Use a shared queue and separate workers when jobs must:

- Survive web process restarts.
- Run outside request-serving processes.
- Be distributed across one or more worker machines.

Keep the inline processor when those operational guarantees are unnecessary; it has fewer moving parts and requires no external service.

## Installing the Redis Processor

Redis support is provided by a separate gem:

```shell
$ bundle add async-job-processor-redis
```

Ensure a Redis service is available to both the Rails and worker processes.

## Configuring the Queue

Replace the built-in `default` queue definition in `config/initializers/async_job.rb`:

```ruby
require "async/job/processor/redis"

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis, prefix: "my-application:#{Rails.env}:default"
	end
end
```

The processor connects to Redis on its local default endpoint unless another endpoint is provided. The Rails process and worker must use the same endpoint and prefix. Use different prefixes for each application, Rails environment, and independently processed queue.

## Starting Workers

Run the bundled worker from the Rails application root so it can load `config/environment.rb`:

```shell
$ RAILS_ENV=production bundle exec async-job-adapter-active_job-server
```

The server loads the Rails environment and starts every defined queue. The service container supervises worker instances and reports their readiness.

If the command cannot run from the application root, set `RAILS_ROOT` explicitly:

```shell
$ RAILS_ROOT=/srv/my-application RAILS_ENV=production bundle exec async-job-adapter-active_job-server
```

## Selecting Queues

Worker groups can listen to a subset of definitions. Provide their names as a comma-separated list:

```shell
$ ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES=default,critical bundle exec async-job-adapter-active_job-server
```

The values must be definition names, not aliases, and should not contain spaces. Run at least one worker group for every Redis-backed definition that should make progress.

## Deployment Checklist

Before sending production traffic, confirm that:

- Rails and workers deploy the same application code and queue configuration.
- Both process types use the same `RAILS_ENV`, Redis endpoint, and queue prefixes.
- Each required queue definition has an active worker group.
- Jobs define appropriate Active Job retry and discard behavior for expected failures.
- Redis persistence and availability match the durability requirements of the application.

An inline definition cannot transfer jobs into another process. If a job runs in the web process or never appears in Redis, confirm that the Rails process actually replaced the built-in inline definition.

## Troubleshooting

### Jobs Do Not Reach the Worker

Confirm that both process types load the same definition, Redis endpoint, prefix, and Rails environment. Also verify that the job's `queue_as` value resolves to that definition.

### The Worker Cannot Load Rails

Run the command from the Rails application root, or set `RAILS_ROOT` to the directory containing `config/environment.rb`.

### A Selected Queue Does Not Start

Check that `ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAMES` contains comma-separated definition names without spaces. An alias is not a worker target.

### `perform_later` Still Waits for the Job

The Rails process is still using the inline definition. Ensure the Redis initializer loads in that environment and replaces `default`, then restart the process.
