# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/job/adapter/active_job/environment"

describe Async::Job::Adapter::ActiveJob::Environment do
	let(:environment) {Object.new.extend(subject)}
	
	with "#preload" do
		it "loads the Rails environment by default" do
			expect(environment.preload).to be == ["config/environment"]
		end
	end
end
