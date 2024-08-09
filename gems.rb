# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

source "https://rubygems.org"

gemspec

# gem "activejob", ">= 7.1"
# gem "rails", path: "../../ioquatix/rails"
# gem "activejob", path: "../../ioquatix/rails/activejob"
# gem "async-job", path: "../async-job"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "decode"
	gem "rubocop"
	
	gem 'sus-fixtures-async'
	gem 'sus-fixtures-console'
	gem 'console-adapter-rails', "~> 0.4.1"
	
	gem "bake-test"
	gem "bake-test-external"
	
	gem "rails", "~> 7.1"
	
	gem "fiber-storage"
end
