# Async::Job::Adapter::AsyncJob

Provides an adapter for ActiveJob on top of `Async::Job`.

[![Development Status](https://github.com/socketry/async-job-adapter-active_job/workflows/Test/badge.svg)](https://github.com/socketry/async-job-adapter-active_job/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-job-adapter-active_job/) for more details.

  - [Getting Started](https://socketry.github.io/async-job-adapter-active_job/guides/getting-started/index) - This guide explains how to use `async-job-adapter-active_job` to run Rails Active Job workloads with inline or Redis-backed queues.

  - [Testing](https://socketry.github.io/async-job-adapter-active_job/guides/testing/index) - This guide explains how to test Active Job workloads without running `async-job` queues inline during every test.

  - [Production Deployment](https://socketry.github.io/async-job-adapter-active_job/guides/production-deployment/index) - This guide explains how to deploy `async-job-adapter-active_job` with Redis-backed queues and separate worker processes.

  - [Queue Configuration](https://socketry.github.io/async-job-adapter-active_job/guides/queue-configuration/index) - This guide explains how to configure `async-job` queue definitions, route Active Jobs, and adopt the adapter incrementally.

## Releases

Please see the [project releases](https://socketry.github.io/async-job-adapter-active_job/releases/index) for all releases.

### v0.18.4

  - Fix handling of `enqueue_at` with timestamp.

### v0.18.0

  - Default to per-fiber isolation.

### v0.17.0

  - Fix health check.

### v0.16.3

  - Actually use `container_options`. I have been working too much.

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

## Contributing

We welcome contributions to this project.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature.'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create a new pull request.

### Running Tests

To run the test suite:

``` bash
$ bundle exec sus
```

### Making Releases

To make a new release:

``` bash
$ bundle exec bake gem:release:patch # or minor or major
```

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
