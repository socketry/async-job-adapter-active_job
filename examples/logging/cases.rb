#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_job'

if ARGV.include? '--proposed'
	require_relative 'proposed'
end

class GoodJob < ActiveJob::Base
	queue_as :default
	
	def perform
		puts 'Hello, world!'
	end
end

class BadJob < ActiveJob::Base
	queue_as :default
	
	def perform
		raise 'This is a bad job!'
	end
end

class RetryJob < ActiveJob::Base
	queue_as :default
	retry_on StandardError, wait: 5.seconds, attempts: 3
	
	def perform
		raise 'This is a bad job!'
	end
end

class DiscardJob < ActiveJob::Base
	queue_as :default
	discard_on StandardError
	
	def perform
		raise 'This is a bad job!'
	end
end

class DefaultDiscardRaiseJob < ActiveJob::Base
	discard_on(Exception) do |job, error|
		raise error
	end
	
	def perform
		raise 'This is a bad job!'
	end
end

def job_server_execute(job_data)
	ActiveJob::Base.execute(job_data)
rescue => error
	# (Q) Should we log this here? Did Rails already log it?
	$stderr.puts error.full_message
end

$stdout.puts "### Case 1: Successful Job\n\n```"
job_data = GoodJob.new.serialize
job_server_execute(job_data)
$stdout.puts "```\n\n"

$stdout.puts "### Case 2: Bad Job\n\n```"
job_data = BadJob.new.serialize
job_server_execute(job_data)
$stdout.puts "```\n\n"

$stderr.puts "### Case 3: Error in Job Server\n\n```"
job_data = {'job_class' => 'DoesNotExistJob'}
job_server_execute(job_data)
$stdout.puts "```\n\n"

$stdout.puts "### Case 4: Retry Job\n\n```"
job_data = RetryJob.new.serialize
job_server_execute(job_data)
$stdout.puts "```\n\n"

$stdout.puts "### Case 5: Discard Job\n\n```"
job_data = DiscardJob.new.serialize
job_server_execute(job_data)
$stdout.puts "```\n\n"

$stdout.puts "### Case 6: Default Discard Raise Job\n\n```"
job_data = DefaultDiscardRaiseJob.new.serialize
job_server_execute(job_data)
$stdout.puts "```\n\n"
