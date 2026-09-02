# Testing

This guide explains how to test Active Job workloads without running `async-job` queues inline during every test.

## Recommended Configuration

Configure the adapter for the application in `config/application.rb` so development and production use the same Active Job integration:

```ruby
module MyApplication
	class Application < Rails::Application
		config.active_job.queue_adapter = :async_job
	end
end
```

Override the adapter in `config/environments/test.rb`:

```ruby
Rails.application.configure do
	config.active_job.queue_adapter = :test
end
```

The Rails test adapter records enqueued jobs instead of sending them to an `async-job` processor. This keeps tests deterministic, prevents the built-in inline queue from performing jobs unexpectedly, and enables Rails' standard Active Job test helpers.

Keeping `:async_job` in the application configuration still exercises the adapter during development. Restricting it to production would make development behave differently from the deployed application.

## Testing Job Behavior

Use `perform_now` when testing the behavior implemented by a job. This invokes the job directly without involving a queue adapter:

```ruby
class SearchIndexRefreshJobTest < ActiveJob::TestCase
	test "refreshes the product index" do
		product = products(:example)
		
		assert_changes ->{product.reload.indexed_at} do
			SearchIndexRefreshJob.perform_now(product.id)
		end
	end
end
```

## Testing Enqueueing

Use `assert_enqueued_with` to verify that application code submits the expected job and arguments:

```ruby
class ProductTest < ActiveSupport::TestCase
	include ActiveJob::TestHelper
	
	test "schedules an index refresh" do
		product = products(:example)
		
		assert_enqueued_with(job: SearchIndexRefreshJob, args: [product.id]) do
			product.schedule_index_refresh
		end
	end
end
```

Rails also provides `assert_enqueued_jobs` when only the number of submitted jobs matters.

## Performing Enqueued Jobs

Use `perform_enqueued_jobs` when a test needs to exercise the code that enqueues a job and the job itself:

```ruby
class ProductTest < ActiveSupport::TestCase
	include ActiveJob::TestHelper
	
	test "refreshes the index asynchronously" do
		product = products(:example)
		
		perform_enqueued_jobs do
			product.schedule_index_refresh
		end
		
		assert product.reload.indexed_at
	end
end
```

The helper performs jobs captured by the Rails test adapter within the block. It does not start an `async-job` processor or worker.

## Testing Production Queue Integration

Tests using `:test` verify job behavior and enqueueing through Active Job, but they do not exercise the production queue transport. Cover Redis-backed definitions and separate workers with a focused integration or deployment smoke test using the same queue configuration as production.

Such a test should submit a uniquely identifiable job, wait for a worker to consume it, and verify its externally visible result. Keep this separate from the unit test suite so ordinary tests do not depend on Redis, worker timing, or another process.
