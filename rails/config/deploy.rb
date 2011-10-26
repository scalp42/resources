require 'capistrano/ext/multistage'
set :application, "<application-name>"
set :repository, "<git-repository>"
set :user, "ubuntu"
set :stages, %w(staging production)
set :default_stage, "staging"

set :use_sudo, false
set :scm_verbose, true
default_run_options[:pty] = true
set :copy_exclude, [".git",".gitignore", "config/mongoid.yml"] # added mongoid.yml due to recent yaml and embedded ruby problems
set :deploy_via, :remote_cache
set :keep_releases, 5
set :scm, :git

role :web, "<ip-or-domain>"
role :app, "<ip-or-domain>"
role :db,  "<ip-or-domain>", primary: true

##
# Using a mongoid.yml config file in shared directory due to recent problems with yaml and embedded ruby
##
before "deploy:symlink", :mongoid_hack
desc "Copy mongoid config"
task :mongoid_hack do
  run "ln -s #{shared_path}/mongoid.yml #{release_path}/config/mongoid.yml"
end

before "deploy:symlink", :bundle_deployment
desc "Bundle deployment"
task :bundle_deployment do
  run "cd #{release_path} && RAILS_ENV=#{rails_env} bundle install --deployment --without development test"
end

after "bundle_deployment", :precompile_assets
desc "Precompiles assets"
task :precompile_assets, role: :app do
  run "cd #{release_path} && RAILS_ENV=#{rails_env} bundle exec rake assets:precompile"
end

after "deploy:update", "deploy:restart"
namespace :deploy do
  desc "Start thin"
  task :start, role: :app do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} sudo bundle exec thin -C config/thin/#{rails_env}.yml start"
  end
  
  desc "Start thin"
  task :stop, role: :app do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} sudo bundle exec thin -C config/thin/#{rails_env}.yml stop"
  end
  
  desc "Restart thin"
  task :restart, role: :app do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} sudo bundle exec thin -C config/thin/#{rails_env}.yml restart"
  end
end
