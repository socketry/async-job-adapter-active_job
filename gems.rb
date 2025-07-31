# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

source "https://rubygems.org"

gemspec

gem "agent-context"

# gem "activejob", ">= 8.0"
# gem "rails", path: "../../ioquatix/rails"
# gem "activejob", path: "../../ioquatix/rails/activejob"
# gem "async-job", path: "../async-job"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "decode"
	gem "rubocop"
	gem "rubocop-socketry"
	
	gem "sus-fixtures-async"
	gem "sus-fixtures-console"
	
	gem "console-adapter-rails"
	
	gem "bake-test"
	gem "bake-test-external"
	
	gem "rails", "~> 8.0"
	
	gem "fiber-storage"
end
