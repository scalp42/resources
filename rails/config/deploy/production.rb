set :branch, "production"
set :stage, "production"
set :rails_env, "production"
set :deploy_to, "/data/www/#{application}/#{stage}"
ssh_options[:keys] = ["~/.ssh/my-key.pem"]
