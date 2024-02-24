# Async::Job::Adapter::AsyncJob

Provides an adapter for ActiveJob on top of `Async::Job`.

[![Development Status](https://github.com/socketry/async-job-adapter-active_job/workflows/Test/badge.svg)](https://github.com/socketry/async-job-adapter-active_job/actions?workflow=Test)

## Usage

Basically, just add this gem to your gemfile:

``` shell
$ bundle add async-job-adapter-active_job
```

To run a server, create a service file, e.g. `job-server.rb` with the following content:

``` ruby
#!/usr/bin/env async-service

require 'async/job/adapter/active_job/service'

service "job-server" do
	include Async::Job::Adapter::ActiveJob::Service
end
```

Then run it:

``` shell
$ bundle exec ./job-server.rb
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
