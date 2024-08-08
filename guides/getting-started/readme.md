# Getting Started

This guide explains how to get started with the `async-job-active_job-adapter` gem.

## Installation

Add the gem to your Rails project:

``` bash
$ bundle add async-job-active_job-adapter
```

## Core Concepts

The `async-job-active_job-adapter` gem provides an Active Job adapter for the `async-job` gem. This allows you to use the `async-job` gem with Rails' built-in Active Job framework.

- The {ruby Async::Job::ActiveJob::Dispatcher} class manages zero or more pipelines, which consist of job queueing and job processing.
- The {ruby Async::Job::ActiveJob::Railtie} class provides a convenient interface for configuring the integration.

In general, `Async::Job` has a concept of queues, where jobs enter into a queue, may get serialized to a backend, then deserialized and processed. This ActiveJob adapter provides {ruby Async::Job::ActiveJob::Interface} which goes at the head of the queue, and matches the interface that ActiveJob expects for enqueueing jobs. At the tail of the queue, the {ruby Async::Job::ActiveJob::Executor} class is responsible for processing jobs by dispatching back into ActiveJob.

## Usage

### Configuration

To configure the Active Job adapter, you can use the `config.active_job` block in your Rails application configuration. Here is an example configuration:

``` ruby
# config/initializers/async_job.rb

require 'async/job'
require 'async/job/procossor/redis'
require 'async/job/procossor/inline'

Rails.application.configure do
	# Create a queue for the "default" backend:
	config.async_job.queue_for "default" do
		queue Async::Job::Processor::Redis
	end
	
	# Create a queue named "local" which uses the Inline backend:
	config.async_job.queue_for "local" do
		queue Async::Job::Processor::Inline
	end
end
```

This configuration sets up two queues: one for the Redis backend and one for the Inline backend.

### Running A Server

If you are using a backend that requires a server (e.g. Redis), you will need to run a server. A simple server is provided `async-job-adapter-active_job-server`, which supports running a single queue. You can run this server with the following command:

``` bash
$ bundle exec async-job-adapter-active_job-server
```

You can specify a different queue name using  the`ASYNC_JOB_ADAPTER_ACTIVE_JOB_QUEUE_NAME` environment variable.

Alternatively, you may prefer to run your own service. See the code in `bin/async-job-adapter-active_job-server` for an example of how to run a server using a service definition.

### Enqueuing Jobs

To enqueue a job, you can use the `perform_later` method in your Active Job class. Here is an example:

``` ruby
class MyJob < ApplicationJob
	queue_as :default

	def perform(message)
		puts message
	end
end

MyJob.perform_later("Hello, world!")
```
