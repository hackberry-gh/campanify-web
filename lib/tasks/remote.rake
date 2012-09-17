namespace :rake do
  task :seed do
    run("cd #{deploy_to}/current; /usr/bin/rake db:seed")
  end
end