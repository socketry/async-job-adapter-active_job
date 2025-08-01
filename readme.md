# Async::Job::Adapter::AsyncJob

Provides an adapter for ActiveJob on top of `Async::Job`.

[![Development Status](https://github.com/socketry/async-job-adapter-active_job/workflows/Test/badge.svg)](https://github.com/socketry/async-job-adapter-active_job/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-job-adapter-active_job/) for more details.

  - [Getting Started](https://socketry.github.io/async-job-adapter-active_job/guides/getting-started/index) - This guide explains how to get started with the `async-job-adapter-active_job` gem.

## Releases

Please see the [project releases](https://socketry.github.io/async-job-adapter-active_job/releases/index) for all releases.

### v0.16.2

  - Add default count (nil = process count).

### v0.16.1

  - Fixed `ThreadLocalDispatcher` to correctly handle `status_string`.

### v0.16.0

  - Add container options for controlling number of workers and health check timeout.
  - Add `status_string` method to `Dispatcher` for better process titles.

### v0.15.0

  - Fix handling of scheduled jobs with proper `scheduled_at` assignment.
  - 100% documentation coverage.
  - 100% test coverage.
  - Modernize code formatting and structure.
  - Fix typo in gem name (\#7).

### v0.14.1

  - Ensure the adapter wraps enqueue operations with `Sync` (\#10).

### v0.14.0

  - Support for running multiple queues.
  - Minor documentation fixes.

### v0.13.0

  - Add support for `:async_job` queue adapter name.
  - Require `active_job` in the executor.
  - Updated logging examples and documentation.
  - Remove `thread-local` gem dependency.
  - Improve error handling - don't log failures as ActiveJob already handles this.

### v0.12.1

  - Force string names for queue identifiers, fixes \#5.

### v0.12.0

  - Improved error handling - let ActiveJob handle retry logic.

### v0.11.0

  - Prefer `define_queue` and `alias_queue` methods for queue configuration.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
