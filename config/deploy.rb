require "bundler/capistrano"

set :user, "root"
set :password, "8rENJNLD"

set :application, "campanify-web"
set :repository,  "git@78.47.40.172:/opt/git/campanify-web.git"

set :scm, :git
set :scm_username, "git"
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :deploy_to, "/var/www/campanify/web"

role :web, "campanify.it"                          # Your HTTP server, Apache/etc
role :app, "campanify.it"                          # This may be the same as your `Web` server
role :db,  "campanify.it", :primary => true # This is where Rails migrations will run
# role :db,  "your slave db-server here"

# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end
