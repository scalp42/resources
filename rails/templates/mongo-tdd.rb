git :init

run "rm public/index.html app/assets/images/rails.png"

file "Gemfile", <<-END
source 'http://rubygems.org'

gem 'rails', '3.2.12'

##
# Database
gem 'mongoid', '3.1.0'

##
# Authentication
# gem 'devise', '2.2.3'
# gem 'devise-encryptable', '0.1.1'

##
# Views
# gem 'haml', '3.1.6'
# gem 'simple_form', '2.0.2'

##
# Uploads & Assets
# gem 'paperclip', '3.4.0'
# gem 'mongoid-paperclip', '0.0.8', require: 'mongoid_paperclip'
# gem 'asset_sync', '0.5.4'
# gem 'aws-sdk', '1.8.1.3'

##
# Server and deployment
# gem 'unicorn', '4.6.0'
# gem 'capistrano', '2.14.2'
# gem 'capistrano-ext', '1.2.1'
# gem 'whenever', '0.8.2', require: false

group :assets do
  gem 'coffee-rails', '3.2.2'
  gem 'uglifier', '1.3.0'
  gem 'jquery-rails', '2.2.1'
  gem 'less', '2.2.2'
  gem 'less-rails', '2.2.6'
end

group :development do
  gem 'ruby-debug19', '0.11.6'
  gem 'therubyracer', '0.11.3', platforms: :ruby
end

group :test do
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'rspec-rails'
  gem 'guard-rspec'
  gem 'mongoid-rspec'
  gem 'database_cleaner'
  gem 'spork'
  gem 'guard-spork'
  gem 'cucumber-rails', require: false
  gem 'guard-cucumber'
end

END

file "LICENSE", <<-END
Copyright (c) 2013 Your Name

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
END

git :add => "."
git :commit => "-m \"Initial commit\""

run "bundle install"
run "rails g mongoid:config"
run "rails g rspec:install"
run "mkdir spec/support spec/models spec/routing features/support features/step_definitions"
run "touch spec/support/.gitkeep spec/models/.gitkeep spec/routing/.gitkeep features/step_definitions/.gitkeep"
run "guard init rspec"
run "spork --bootstrap"
run "guard init spork"

file "Guardfile", <<-END
guard 'cucumber' do
  watch(%r{^features/.+\.feature$})
  watch(%r{^features/support/.+$})          { 'features' }
  watch(%r{^features/step_definitions/(.+)_steps\.rb$}) { |m| Dir[File.join("**/\#{m[1]}.feature")][0] || 'features' }
end

guard 'rspec', :version => 2 do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/\#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

  # Rails example
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/\#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/\#{m[1]}\#{m[2]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| ["spec/routing/\#{m[1]}_routing_spec.rb", "spec/\#{m[2]}s/\#{m[1]}_\#{m[2]}_spec.rb", "spec/acceptance/\#{m[1]}_spec.rb"] }
  watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
  watch('config/routes.rb')                           { "spec/routing" }
  watch('app/controllers/application_controller.rb')  { "spec/controllers" }
  
  # Capybara request specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/\#{m[1]}_spec.rb" }
  
  # Turnip features and steps
  watch(%r{^spec/acceptance/(.+)\.feature$})
  watch(%r{^spec/acceptance/steps/(.+)_steps\.rb$})   { |m| Dir[File.join("**/\#{m[1]}.feature")][0] || 'spec/acceptance' }
end

guard 'spork', :cucumber_env => { 'RAILS_ENV' => 'test' }, :rspec_env => { 'RAILS_ENV' => 'test' } do
  watch('config/application.rb')
  watch('config/environment.rb')
  watch('config/environments/test.rb')
  watch(%r{^config/initializers/.+\.rb$})
  watch('Gemfile')
  watch('Gemfile.lock')
  watch('spec/spec_helper.rb') { :rspec }
  watch('test/test_helper.rb') { :test_unit }
  watch(%r{features/support/}) { :cucumber }
end

END

file "spec/spec_helper.rb", <<-END
require 'rubygems'
require 'spork'

Spork.prefork do
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'capybara/rails'
  require 'database_cleaner'
  require 'rails/mongoid'
  require File.dirname(__FILE__) + "/support/controller_macros"
  
  Spork.trap_class_method(Rails::Mongoid, :load_models)
  Spork.trap_method(Rails::Application::RoutesReloader, :reload!)
  
  Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
  
  RSpec.configure do |config|
    config.mock_with :rspec
    
    config.before(:suite) do
      DatabaseCleaner.orm = "mongoid"
      DatabaseCleaner.strategy = :truncation
    end
    
    config.before(:each) do
      DatabaseCleaner.clean
    end
    
    config.include Mongoid::Matchers
    config.include Devise::TestHelpers, type: :controller
    config.include ControllerMacros, type: :controller
  end
end

Spork.each_run do
  FactoryGirl.reload
end

END

file "features/support/env.rb", <<-END
require 'rubygems'
require 'spork'

Spork.prefork do
  require 'cucumber/rails'
  Capybara.default_selector = :css
end

Spork.each_run do
  ActionController::Base.allow_rescue = false
  
  begin
    DatabaseCleaner.orm = 'mongoid'
    DatabaseCleaner.strategy = :truncation
  rescue NameError
    raise "You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it."
  end
  
  Cucumber::Rails::Database.javascript_strategy = :truncation
end

END

git :add => "."
git :commit => "-m \"Development and test suite set up\""
