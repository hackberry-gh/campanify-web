source 'http://rubygems.org'
source "http://bundler-api.herokuapp.com"

ruby '1.9.3'

gem 'rails', 												'3.2.11'
gem 'pg'
gem 'foreman'
gem 'unicorn'
gem 'devise'
gem 'heroku'
gem 'heroku-api'
gem 'delayed_job_active_record'
gem 'fog'
gem 'pusher'
gem 'colored'
gem 'memcachier'
gem 'dalli'
gem 'activeadmin'
gem 'quiet_assets'

group :assets do
  gem 'sass-rails',   							'~> 3.2.3'
  gem 'coffee-rails', 							'~> 3.2.1'
  gem 'uglifier', 									'>= 1.0.3'
end

gem 'jquery-rails'

group :development do
	gem 'hirb'
	gem 'wirble'
end

group :test do
	gem 'database_cleaner', 					'~> 0.8.0'
end

group :test, :development do
	gem 'rspec-rails', 								'~> 2.11.0'
	gem 'capybara', 									'~> 1.1.2'
end

gem 'capistrano'										
gem 'rvm-capistrano'