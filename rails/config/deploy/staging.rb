set :branch, "staging"
set :stage, "staging"
set :rails_env, "staging"
set :deploy_to, "/data/www/#{application}/#{stage}"
ssh_options[:keys] = ["~/.ssh/my-key.pem"]
