# frozen_string_literal: true

require_relative "lib/async/job/adapter/active_job/version"

Gem::Specification.new do |spec|
	spec.name = "async-job-adapter-active_job"
	spec.version = Async::Job::Adapter::ActiveJob::VERSION
	
	spec.summary = "A asynchronous job queue for Ruby on Rails."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-job-adapter-active_job",
	}
	
	spec.files = Dir['{lib}/**/*', '*.md', base: __dir__]
	
	spec.required_ruby_version = ">= 3.0"
	
	spec.add_dependency "async-job", "~> 0.5"
	spec.add_dependency "async-service", "~> 0.8"
	spec.add_dependency "thread-local"
end
