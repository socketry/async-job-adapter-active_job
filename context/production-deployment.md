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

redis_endpoint = Async::Redis::Endpoint.parse(ENV.fetch("REDIS_URL"))

Rails.application.configure do
	config.async_job.define_queue "default" do
		dequeue Async::Job::Processor::Redis, endpoint: redis_endpoint
	end
end
```

Set `REDIS_URL` in both the Rails and worker process environments. It may use the `redis://` or `rediss://` scheme and include credentials, a port, and a database number:

```shell
$ REDIS_URL=redis://redis.example.com:6379/0 bundle exec async-job-adapter-active_job-server
```

Without an explicit endpoint, the processor connects to `redis://localhost:6379`. With one logical queue, the default `async-job` prefix is sufficient. Configure distinct, stable prefixes when multiple queue definitions share a Redis endpoint.

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
