#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_job'

module ModuleJob
end

$stdout.puts "### Case 1: Failed Module Job\n\n```"
begin
	ActiveJob::Base.execute({
		'job_class' => ModuleJob.name,
	})
rescue => error
	$stdout.puts error.full_message
end
$stdout.puts "```"

class BareObjectJob
end

$stdout.puts "### Case 2: Failed Bare Object Job\n\n```"
begin
	ActiveJob::Base.execute({
		'job_class' => BareObjectJob.name,
	})
rescue => error
	$stdout.puts error.full_message
end
$stdout.puts "```"

class BadDeserializeJob
	def deserialize(job_data)
		raise 'This is a bad deserialize!'
	end
end

$stdout.puts "### Case 3: Failed Deserialize Job\n\n```"
begin
	ActiveJob::Base.execute({
		'job_class' => BadDeserializeJob.name,
	})
rescue => error
	$stdout.puts error.full_message
end
$stdout.puts "```"

class BadTimeJob < ActiveJob::Base
	queue_as :default
	
	def perform
		raise 'This is a bad time job!'
	end
end

$stdout.puts "### Case 4: Failed Time Job\n\n```"
begin
	ActiveJob::Base.execute({
		'job_class' => BadTimeJob.name,
		'enqueued_at' => "bad time",
		
	})
rescue => error
	$stdout.puts error.full_message
end
$stdout.puts "```"
