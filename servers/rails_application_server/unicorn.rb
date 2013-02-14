root = "/home/ec2-user/applications/application/production/current"
working_directory root
pid "#{root}/tmp/pids/unicorn.pid"
stderr_path "#{root}/log/unicorn.log"
stdout_path "#{root}/log/unicorn.log"
listen "/tmp/unicorn.application.sock"
worker_processes 1
timeout 30
