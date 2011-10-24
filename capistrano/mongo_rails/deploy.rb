require 'capistrano/ext/multistage'
set :application, "application-name"
set :repository,  "git-repository"
set :user, "ubuntu"
set :stages, %w(staging production)
set :default_stage, "staging"
default_run_options[:pty] = true
set :use_sudo, false
set :copy_exclude, [".git",".gitignore"]
set :deploy_via, :remote_cache
set :keep_releases, 5
set :scm, :git
set :scm_verbose, true

role :web, "my.ip.to.server"
role :app, "my.ip.to.server"
role :db,  "my.ip.to.server", primary: true

before "deploy:symlink", :bundle_deployment
desc "Bundle deployment"
task :bundle_deployment do
  run "cd #{release_path} && bundle install --deployment --without development test"
end

after "bundle_deployment", :precompile_assets
desc "Precompiles assets"
task :precompile_assets, role: :app do
  run "cd #{release_path} && RAILS_ENV=#{rails_env} bundle exec rake assets:precompile"
end
