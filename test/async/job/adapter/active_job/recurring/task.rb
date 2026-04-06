# frozen_string_literal: true

# Released under the MIT License.

require "async/job/adapter/active_job/recurring/task"

describe Async::Job::Adapter::ActiveJob::Recurring::Helper do
	let(:helper) {Async::Job::Adapter::ActiveJob::Recurring::Helper}
	
	it "normalizes 'every N seconds'" do
		result = helper.normalize_schedule("every 5 seconds")
		expect(result).to be == "*/5 * * * * *"
	end
	
	it "normalizes 'every N minutes'" do
		result = helper.normalize_schedule("every 10 minutes")
		expect(result).to be == "0 */10 * * * *"
	end
	
	it "normalizes 'every N hours'" do
		result = helper.normalize_schedule("every 3 hours")
		expect(result).to be == "0 0 */3 * * *"
	end
	
	it "returns empty string for empty input" do
		result = helper.normalize_schedule("")
		expect(result).to be == ""
	end
	
	it "passes through non-matching schedule as-is" do
		cron_str = "0 0 * * *"
		result = helper.normalize_schedule(cron_str)
		expect(result).to be == cron_str
	end
	
	it "parses valid cron string" do
		cron = helper.parse_cron("0 0 * * *")
		expect(cron).not.to be == nil
		expect(cron).to be_a(Fugit::Cron)
	end
	
	it "returns nil for invalid cron string" do
		cron = helper.parse_cron("not a valid cron")
		expect(cron).to be == nil
	end
	
	it "constantizes valid constant name" do
		klass = helper.constantize("ActiveJob::Base")
		expect(klass).to be == ActiveJob::Base
	end
	
	it "returns nil for non-existent constant" do
		klass = helper.constantize("NonExistentClass")
		expect(klass).to be == nil
	end
end
