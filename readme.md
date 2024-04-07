# Async::Job::Adapter::AsyncJob

Provides an adapter for ActiveJob on top of `Async::Job`.

[![Development Status](https://github.com/socketry/async-job-adapter-active_job/workflows/Test/badge.svg)](https://github.com/socketry/async-job-adapter-active_job/actions?workflow=Test)

## Usage

Please see the [project documentation](https://socketry.github.io/async-job-adapter-active_job/) for more details.

  - [Getting Started](https://socketry.github.io/async-job-adapter-active_job/guides/getting-started/index) - This guide explains how to get started with the `async-job-active_job-adapter` gem.

### Configuration

``` ruby
Rails.application.configure do
	config.async_job.backend_for :default, :critical do
		queue Async::Job::Backend::Redis, endpoint: Async::IO::Endpoint.tcp('redis.local')
	end
	
	config.async_job.aliases_for :default, :email
	
	config.async_job.backend_for :local do
		queue Async::Job::Backend::Inline
	end
end
```

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

This project uses the [Developer Certificate of Origin](https://developercertificate.org/). All contributors to this project must agree to this document to have their contributions accepted.

### Contributor Covenant

This project is governed by the [Contributor Covenant](https://www.contributor-covenant.org/). All contributors and participants agree to abide by its terms.
