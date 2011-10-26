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

role :web, "<ip-or-domain>"
role :app, "<ip-or-domain>"
role :db,  "<ip-or-domain>", primary: true

after "deploy:setup", "wordpress:shared_directories"
before "deploy:symlink", "wordpress:shared_resources"

desc "Wordpress capistrano tasks"
namespace :wordpress do
  desc "Sets up shared directories"
  task :shared_directories do
    run "mkdir -p #{shared_path}/logs"
    run "chmod g+w #{shared_path}/logs"
    run "mkdir -p #{shared_path}/uploads"
    run "chmod g+w #{shared_path}/uploads"
  end
  
  desc "Symlinks shared resources"
  task :shared_resources do
    run "ln -s #{shared_path}/uploads #{release_path}/wp-content/uploads"
  end
end
