git :init

file "Gemfile", <<-END
source 'http://rubygems.org'

gem 'rails', '3.1.0'

gem "mongoid", "~> 2.3.0"
gem "bson_ext", "~> 1.4.0"
gem "mongo", "~> 1.4.0"
gem "bson", "~> 1.4.0"

group :assets do
  gem 'sass-rails', "  ~> 3.1.0"
  gem 'coffee-rails', "~> 3.1.0"
  gem 'uglifier'
end

gem 'jquery-rails'

gem "rspec-rails", :group => [:test, :development]
group :test do
  gem "factory_girl_rails"
  gem "capybara"
  gem "guard-rspec"
  gem "database_cleaner"
  gem "mongoid-rspec"
  gem "spork", "~> 0.9.0.rc9"
end
END

file "LICENSE", <<-END
Copyright (c) 2011 Your Name

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
run "rails g rspec:install"
run "mkdir spec/support spec/models spec/routing"
run "touch spec/support/.gitkeep spec/models/.gitkeep spec/routing/.gitkeep"
run "guard init rspec"

git :add => "."
git :commit => "-m \"Test suite installed\""

run "rails generate mongoid:config"

git :add => "."
git :commit => "-m \"Mongoid installed\""
