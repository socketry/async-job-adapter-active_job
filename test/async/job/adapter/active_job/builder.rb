require 'async/job/adapter/active_job/builder'
require 'async/job/adapter/active_job/queue_adapter'
require 'async/job/adapter/active_job/queue_handler'
require 'async/job/backend/redis'

require 'sus/fixtures/async/reactor_context'

describe Async::Job::Adapter::ActiveJob::Builder do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:builder) {subject.new}
	
	it "can build a basic queue" do
		builder.queue Async::Job::Backend::Redis
		
		pipeline = builder.build
		
		expect(pipeline.adapter).to be_a(Async::Job::Adapter::ActiveJob::QueueAdapter)
		expect(pipeline.queue).to be_a(Async::Job::Backend::Redis::Server)
	end
end
