require 'capistrano/ext/multistage'
set :application, "<application-name>"
set :repository, "<git-repository>"
set :user, "ubuntu"
set :stages, %w(staging production)
set :default_stage, "staging"

set :use_sudo, false
set :scm_verbose, true
default_run_options[:pty] = true
set :copy_exclude, [".git",".gitignore"]
set :deploy_via, :remote_cache
set :keep_releases, 5
set :scm, :git

role :web, "<my.ip.to.server>"
role :app, "<my.ip.to.server>"
role :db,  "<my.ip.to.server>", primary: true

after "deploy:setup", "wordpress:shared_directories"
before "deploy:symlink", "wordpress:shared_resources"

desc "Wordpress capistrano tasks"
namespace :wordpress do
  desc "Shared directories"
  task :shared_directories do
    run "mkdir -p #{shared_path}/logs"
    run "chmod g+w #{shared_path}/logs"
    run "mkdir -p #{shared_path}/uploads"
    run "chmod g+w #{shared_path}/uploads"
  end
  
  desc "Symlink files"
  task :shared_resources do
    run "ln -s #{shared_path}/uploads #{release_path}/wp-content/uploads"
  end
end
