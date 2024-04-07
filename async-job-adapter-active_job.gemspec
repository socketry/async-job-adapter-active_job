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
	
	spec.homepage = "https://github.com/socketry/async-job-adapter-active_job"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-job-adapter-active_job/",
		"source_code_uri" => "https://github.com/socketry/async-job-adapter-active_job.git",
	}
	
	spec.files = Dir['{bin,lib}/**/*', '*.md', base: __dir__]
	
	spec.executables = ["async-job-adapter-active_job-server"]
	
	spec.required_ruby_version = ">= 3.1"
	
	spec.add_dependency "async-job", "~> 0.5"
	spec.add_dependency "async-service", "~> 0.12"
	spec.add_dependency "thread-local"
end
