# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Carmine Paolino.

require "async/job/adapter/active_job/environment"

describe Async::Job::Adapter::ActiveJob::Environment do
	let(:environment) do
		Class.new do
			extend Async::Job::Adapter::ActiveJob::Environment
		end
	end
	
	it "has sensible default health timings" do
		expect(environment.health_check_timeout({})).to be == 30
		expect(environment.health_check_interval({})).to be == 15.0
	end
	
	it "can override health timings from the environment" do
		overrides = {
			"ASYNC_JOB_ADAPTER_ACTIVE_JOB_HEALTH_CHECK_TIMEOUT" => "60",
			"ASYNC_JOB_ADAPTER_ACTIVE_JOB_HEALTH_CHECK_INTERVAL" => "10",
		}
		
		expect(environment.health_check_timeout(overrides)).to be == 60.0
		expect(environment.health_check_interval(overrides)).to be == 10.0
	end
	
	it "can disable health checks from the environment" do
		overrides = {
			"ASYNC_JOB_ADAPTER_ACTIVE_JOB_HEALTH_CHECK_TIMEOUT" => "0",
		}
		
		expect(environment.health_check_timeout(overrides)).to be_nil
		expect(environment.health_check_interval(overrides)).to be_nil
	end
end
