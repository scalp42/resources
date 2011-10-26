set :stage, "staging"
ssh_options[:keys] = ["~/.ssh/<pem-key-file>"]
set :deploy_to, "/data/www/#{application}/#{stage}"
set :branch, "#{stage}"
