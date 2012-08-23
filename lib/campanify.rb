# require 'heroku_api'
# require 'rake'

module Campanify
  
  APPS_DIR = "/Users/onuruyar/Sites/campanify/apps"
  
  extend ActiveSupport::Concern
  
  def safe_create(name)
    result = create_app(name)
    if result.is_a?(Hash)
      system "rm -rf #{APPS_DIR}/#{result[:error]}"
      heroku.delete_app(result[:error])
      puts result
    end
    result
  end
  
  def create_account(email, full_name)
    password = ::Devise.friendly_token.first(6)
    user = User.create(email: email, full_name: full_name, password: password, password_confirmation: password)
    if user.persisted?
      {email: user.email, full_name: user.full_name, password: password}
    else
      false
    end  
  end
  
  def create_app(name, account = {email: "admin@campanify.it", full_name: "Campanify Admin", password: Devise.friendly_token.first(6)})    
    app = heroku.post_app.body
    slug = app["name"]
    return nil unless slug
    begin
      app_dir = "#{APPS_DIR}/#{app["name"]}"
      
      mkdir = system("mkdir #{app_dir}")
      return {error: app["name"]} unless mkdir
      
      clone = system("git clone git@heroku.campanify_tech:campanify-app.git #{app_dir} -o heroku")
      return {error: app["name"]} unless clone
      
      file_name = "#{Rails.root}/lib/templates/seeds.rb"
      content = File.read(file_name)
      content = content.gsub(/\$name/, name)
      content = content.gsub(/\$slug/, slug)
      content = content.gsub(/\$admin_email/, account[:email])
      content = content.gsub(/\$admin_full_name/, account[:full_name])        
      content = content.gsub(/\$admin_password/, account[:password])            
      target_file_name = "#{app_dir}/db/seeds.rb"
      system("touch #{target_file_name}")
      File.open(target_file_name, "w") {|file| file.write content}

      file_name = "#{Rails.root}/lib/templates/install.sh"
      content = File.read(file_name)
      content = content.gsub(/\$app_dir/, app_dir)      
      content = content.gsub(/\$name/, name)
      content = content.gsub(/\$slug/, slug)
      target_file_name = "#{app_dir}/install.sh"
      system("touch #{target_file_name}")      
      File.open(target_file_name, "w") {|file| file.write content}
      
      file_name = "#{app_dir}/config/settings.yml"
      content = File.read(file_name)
      content = content.gsub(/localhost:3000/, "#{slug}.herokuapp.com")      
      target_file_name = file_name
      File.open(target_file_name, "w") {|file| file.write content}
      
      chmod = system("cd #{app_dir} && chmod +x install.sh")
      return {error: app["name"]} unless chmod
            
      # rake = system("cd #{app_dir} && bundle exec rake campanify:setup")
      # return {error: app["name"]} unless rake 
      
      install = system("cd #{app_dir} && ./install.sh")
      return {error: app["name"]} unless install
      rm = system("cd #{app_dir} && rm -rf install.sh")
      return {error: app["name"]} unless rm
      
      Hash[File.open("#{app_dir}/.env").read.split("\n").map{|v| v.split("=")}].each do |k,v|
        system("cd #{app_dir} && bundle exec heroku config:add #{k}=#{v}")
      end

      system("cd #{app_dir} && bundle exec heroku run rake db:migrate --account campanify_tech")
      system("cd #{app_dir} && bundle exec heroku run rake db:seed --account campanify_tech")
           
    rescue Exception => e
      return {error: app["name"], description: e}
    end
  end
  
  def heroku
    @heroku ||= ::Heroku::API.new
  end
  
  # def run_rake(task_name)
  #   load File.join(Rails.root, 'lib', 'tasks', 'campanify.rake')
  #   Rake::Task[task_name].invoke
  # end
    
end