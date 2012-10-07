require "rvm/capistrano"

set :user, "campanify"
role :campanify, "campanify.it"

set :rvm_ruby_string, 'ruby-1.9.3-p194@campanify'
set :rvm_type, :user  # Don't use system-wide RVM

default_run_options[:shell] = 'bash'
# set :bundle_cmd, 'source $HOME/.bashrc && bundle'

set :default_environment, {
    'PATH' => "/home/campanify/.rvm/gems/ruby-1.9.3-p194@campanify/bin:/home/campanify/.rvm/gems/ruby-1.9.3-p194@global/bin:/home/campanify/.rvm/rubies/ruby-1.9.3-p194/bin:/home/campanify/.rvm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games",
    'GEM_HOME' => '/home/campanify/.rvm/gems/ruby-1.9.3-p194@campanify',
    'GEM_PATH' => '/home/campanify/.rvm/gems/ruby-1.9.3-p194@campanify',
    # 'BUNDLE_PATH' => '<ruby-dir>/lib/ruby/gems/1.8/gems'  
}

namespace :campanify do
  task :clone_app, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"

    run "cd /home/campanify/apps && git clone git@heroku.com:campanify-app.git #{app_dir} -o heroku"
    puts "=== GIT REPO CLONNED ==="  
    
    file_name = "#{rails_root}/lib/templates/seeds.rb"
    content = File.read(file_name)
    content = content.gsub(/\$name/, campaign_name)
    content = content.gsub(/\$slug/, campaign_slug)
    content = content.gsub(/\$admin_email/, campaign_user_email)
    content = content.gsub(/\$admin_full_name/, campaign_user_full_name)        
    content = content.gsub(/\$admin_password/, campaign_user_password)            
    target_file_name = "#{app_dir}/db/seeds.rb"
    put_respons = put content, target_file_name
    puts "put_respons : #{put_respons}"
    puts "=== SEED.RB GENERATED ==="
    
    file_name = "#{rails_root}/lib/templates/settings.yml"
    content = File.read(file_name)
    content = content.gsub(/localhost:3000/, "#{slug}.campanify.it")      
    content = content.gsub("host_type: filesystem", "host_type: s3")            
    content = content.gsub("storage: file", "storage: fog")                  
    target_file_name = "#{app_dir}/config/settings.yml"
    put_respons = put content, target_file_name    
    puts "=== SETTINGS.YML GENERATED ==="

    file_name = "#{rails_root}/lib/templates/env"
    content = File.read(file_name)
    content = content.gsub(/free/, campaign_plan)      
    content = content.gsub(/bucket/, "campanify_app_#{slug_underscore}")                
    target_file_name = "#{app_dir}/.env"
    put_respons = put content, target_file_name    
    puts "=== .ENV GENERATED ==="
    
    run "cd #{app_dir} && source $HOME/.bashrc && rvm gemset use campanify"
    run "cd #{app_dir} && git remote rm heroku"
    run "cd #{app_dir} && git remote add heroku git@heroku.com:#{slug}.git"           
    run "cd #{app_dir} && git remote add origin git@heroku.com:campanify-app.git"               
    run "cd #{app_dir} && source $HOME/.bashrc && bundle"
    run "cd #{app_dir} && git add ."
    run "cd #{app_dir} && git commit -am 'clonned'"
    run "cd #{app_dir} && git push heroku master"
  end
  
  task :setup_db, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"
    run "cd #{app_dir} && source $HOME/.bashrc && bundle exec heroku run rake db:migrate --app #{slug}"
    run "cd #{app_dir} && source $HOME/.bashrc && bundle exec heroku run rake db:seed --app #{slug}"    
  end
  
  task :backup_db, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"
    run "cd #{app_dir} && source $HOME/.bashrc && heroku pgbackups:capture --expire --app #{slug}"
  end
  
  task :wait_db, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"
    run "cd #{app_dir} && source $HOME/.bashrc && heroku pg:wait --app #{slug}"
  end  
  
  task :restore_db, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"
    run "cd #{app_dir} && source $HOME/.bashrc && heroku pgbackups:restore #{target_db} --confirm #{slug} --app #{slug}"
  end
  
  task :promote_db, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"
    run "cd #{app_dir} && source $HOME/.bashrc && heroku pg:promote #{target_db} --app #{slug}"
  end  
  
  task :remove_app, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"
    run "rm -rf #{app_dir}"
  end
  
  task :update_app, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"    
    run "cd #{app_dir} && git pull origin master"    
    run "cd #{app_dir} && git push heroku master"    
  end
  
  task :push_app, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"    
    run "cd #{app_dir} && git push heroku master"    
  end
  
  task :change_template, :roles => :campanify do
    app_dir = "/home/campanify/apps/#{slug}"    
    run "cp -fr /home/campanify/themes/#{theme} #{app_dir}/db/seeds/themes/#{theme}"
    run "cp -fr /home/campanify/themes_#{theme}_install.seeds.rb #{app_dir}/db/seeds/themes_#{theme}_install.seeds.rb"    
    run "cd #{app_dir} && git add ."    
    run "cd #{app_dir} && git commit -am 'changed to #{theme}'"
    run "cd #{app_dir} && git push heroku master"    
    run "cd #{app_dir} && source $HOME/.bashrc && bundle exec heroku run rake db:seed:themes_#{theme}_install --app #{slug}"     
  end
  
end