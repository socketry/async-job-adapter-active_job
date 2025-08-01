# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "test_job"
require "async/job/adapter/active_job/thread_local_dispatcher"

describe Async::Job::Adapter::ActiveJob::ThreadLocalDispatcher do
	let(:definitions) {{"default" => proc {"test"}}}
	let(:aliases) {{"alias" => "default"}}
	let(:thread_local_dispatcher) {subject.new(definitions, aliases)}
	
	with "#call" do
		it "can call dispatcher with job" do
			job = TestJob.new
			mock_dispatcher = Object.new
			mock_dispatcher.define_singleton_method(:call) {|job|}
			
			mock(thread_local_dispatcher) do |mock|
				mock.replace(:dispatcher) {mock_dispatcher}
			end
			
			expect(mock_dispatcher).to receive(:call).with(job)
			thread_local_dispatcher.call(job)
		end
	end
	
	with "#start" do
		it "can start dispatcher" do
			mock_dispatcher = Object.new
			mock_dispatcher.define_singleton_method(:start) {|name|}
			
			mock(thread_local_dispatcher) do |mock|
				mock.replace(:dispatcher) {mock_dispatcher}
			end
			
			expect(mock_dispatcher).to receive(:start).with("test_queue")
			thread_local_dispatcher.start("test_queue")
		end
	end
	
	with "#keys" do
		it "can get definition keys" do
			keys = thread_local_dispatcher.keys
			expect(keys).to be == ["default"]
		end
	end
	
	with "#status_string" do
		it "can get status string from dispatcher" do
			expect(thread_local_dispatcher.dispatcher).to receive(:status_string).and_return("default (test)")
			
			expect(thread_local_dispatcher.status_string).to be == "default (test)"
		end
	end
end