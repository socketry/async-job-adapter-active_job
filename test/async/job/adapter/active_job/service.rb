# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/job/adapter/active_job/service"
require "fileutils"
require "tmpdir"

describe Async::Job::Adapter::ActiveJob::Service do
	with "#start" do
		it "preloads the application before starting the service" do
			Dir.mktmpdir do |root|
				environment_path = File.join(root, "config/environment.rb")
				FileUtils.mkdir_p(File.dirname(environment_path))
				File.write(environment_path, "# frozen_string_literal: true\n")
				
				evaluator = Struct.new(:root, :preload).new(root, ["config/environment"])
				service = subject.new(Object.new, evaluator)
				service.start
				
				expect($LOADED_FEATURES).to be(:include?, environment_path)
			ensure
				$LOADED_FEATURES.delete(environment_path)
			end
		end
	end
end
