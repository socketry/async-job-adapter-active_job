# Releases

## v0.16.2

  - Add default count (nil = process count).

## v0.16.1

  - Fixed `ThreadLocalDispatcher` to correctly handle `status_string`.

## v0.16.0

  - Add container options for controlling number of workers and health check timeout.
  - Add `status_string` method to `Dispatcher` for better process titles.

## v0.15.0

  - Fix handling of scheduled jobs with proper `scheduled_at` assignment.
  - 100% documentation coverage.
  - 100% test coverage.
  - Modernize code formatting and structure.
  - Fix typo in gem name (\#7).

## v0.14.1

  - Ensure the adapter wraps enqueue operations with `Sync` (\#10).

## v0.14.0

  - Support for running multiple queues.
  - Minor documentation fixes.

## v0.13.0

  - Add support for `:async_job` queue adapter name.
  - Require `active_job` in the executor.
  - Updated logging examples and documentation.
  - Remove `thread-local` gem dependency.
  - Improve error handling - don't log failures as ActiveJob already handles this.

## v0.12.1

  - Force string names for queue identifiers, fixes \#5.

## v0.12.0

  - Improved error handling - let ActiveJob handle retry logic.

## v0.11.0

  - Prefer `define_queue` and `alias_queue` methods for queue configuration.

## v0.10.0

  - Rename "pipeline" concept to "queue" for consistency.

## v0.9.0

  - Update interface to suit upstream async-job changes.

## v0.8.0

  - Add `#start`/`#stop` delegators for better lifecycle management.
  - Performance improvements with benchmarking.

## v0.7.0

  - Major modernization of the gem structure.
  - Improved documentation generation.
  - Drop Ruby 3.0 support.
  - Fix server binary and add default server configuration.

## v0.6.0

  - Update dependency on `async-service`.
  - Add explicit `Environment` class for better configuration.

## v0.5.0

  - Move builder pattern to `async-job` library.
  - Significantly improved test coverage.

## v0.4.0

  - Add Redis workflow support.

## v0.3.0

  - Introduce builder pattern for constructing adapters and queues.
  - Support for multiple queues.

## v0.2.0

  - Add support for basic configuration.
  - Initial test suite.

## v0.1.0

  - Initial extraction of ActiveJob adapter code from `async-job`.
