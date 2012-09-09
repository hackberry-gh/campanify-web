# require 'heroku_api'
# require 'rake'

module Campanify
  
  DEFAULT_ACCOUNT = {
    email: "admin@campanify.it", 
    full_name: "Campanify Admin", 
    password: Devise.friendly_token.first(6)
  }
  
  module Heroku
    extend ActiveSupport::Concern
    def heroku
      @heroku ||= ::Heroku::API.new
    end
  end
  
  module Plans
    class << self
      def all
        %w(town city country earth universal)
      end
      def configuration(plan)
      {
        town: {
          ps: {
            web: 1,
            worker: 0
          },
          addons: {
            "pgbackups" => "auto-week",
            "sendgrid" => "starter",
            "memcachier" => "dev"
          },
          db: 'heroku-postgresql:dev',          
          price: 0
        },
        city: {
          ps: {
            web: 2,
            worker: 1
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "bronze",
            "memcachier" => "100"
          },
          db: 'heroku-postgresql:crane',
          price: 17100          
        },
      }[plan]
    end
    end
  end
  
  module Campaigns
    class << self
      
      include Heroku      
      
      def create_app(name, plan, account = DEFAULT_ACCOUNT)    
        app = heroku.post_app.body
        slug = app["name"]
        return nil unless slug
        begin
          app_dir = "#{APPS_DIR}/#{app["name"]}"

          mkdir = system("mkdir #{app_dir}")
          return {error: app["name"]} unless mkdir

          # heroku accounts:set
          system('git config heroku.account campanify_tech')
          system("git config remote.heroku.url git@heroku.campanify_tech:#{app['name']}.git")

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
          content = content.gsub(/localhost:3000/, "#{slug}.campanify.it")      
          content = content.gsub("host_type: filesystem", "host_type: s3")            
          content = content.gsub("storage: file", "storage: fog")                  
          target_file_name = file_name
          File.open(target_file_name, "w") {|file| file.write content}

          file_name = "#{app_dir}/.env"
          content = File.read(file_name)
          content = content.gsub(/town/, plan)      
          target_file_name = file_name
          File.open(target_file_name, "w") {|file| file.write content}      

          chmod = system("cd #{app_dir} && chmod +x install.sh")
          return {error: app["name"]} unless chmod

          # rake = system("cd #{app_dir} && bundle exec rake campanify:setup")
          # return {error: app["name"]} unless rake 

          current_dir = Dir.pwd
          Dir.chdir(app_dir)
          install = system("cd #{app_dir} && ./install.sh")
          return {error: app["name"]} unless install
          Dir.chdir(current_dir)          

          # rm = system("cd #{app_dir} && rm -rf install.sh")
          #       return {error: app["name"]} unless rm

          Hash[File.open("#{app_dir}/.env").read.split("\n").map{|v| v.split("=")}].each do |k,v|
            system("cd #{app_dir} && bundle exec heroku config:add #{k}=#{v} --app #{app["name"]}")
          end

          system("cd #{app_dir} && bundle exec heroku run rake db:migrate --app #{app["name"]} --trace")
          system("cd #{app_dir} && bundle exec heroku run rake db:seed --app #{app["name"]} --trace")

        rescue Exception => e
          return {error: app["name"], description: e}
        end
      end
      handle_asynchronously :create_app

      def migrate_db(slug, current_plan, target_plan)
        # get configs
        current_config = Campanify::Plans.configuration(current_plan.to_sym)
        config = Campanify::Plans.configuration(target_plan.to_sym)

        # put app on maintenance mode
        heroku.post_app_maintenance(slug, 1)

        # db migration
        # ============

        # add new db addon
        heroku.delete_addon(slug, config[:db]) rescue nil

        heroku.post_addon(slug, config[:db]) 

        # capture backup of current db
        system("heroku pgbackups:capture --expire --app #{slug}")

        # get new db url
        config_vars = heroku.get_config_vars(slug).body
        target_db = config_vars.
                    delete_if{|key,value| !key.include?('POSTGRESQL')}.
                    delete_if{|key,value| value == config_vars['DATABASE_URL']}.
                    keys.first

        # TODO: wait for ready
        waiting = `heroku pg:wait --app #{slug}`
        puts "WAITING #{waiting}"

        # restore new db from backup
        system("heroku pgbackups:restore #{target_db} --app #{slug} --confirm #{slug}")

        # promote new db
        system("heroku pg:promote #{target_db} --app #{slug}")

        # remove old db addon
        heroku.delete_addon(slug, current_config[:db])

        # remove app from maintenance mode
        heroku.post_app_maintenance(slug, 0)
      end
      handle_asynchronously :migrate_db
      
    end
    
  end
  
  extend ActiveSupport::Concern
  include Heroku
  
  def create_app(name, plan = Plans.all.first)
    result = Campaigns.create_app(name, plan)
    if result.is_a?(Hash)
      system "rm -rf #{APPS_DIR}/#{result[:error]}"
      heroku.delete_app(result[:error])
    end
    result
  end
  
  def migrate_db(slug, current_plan, target_plan)
    Campaign.migrate_db(slug, current_plan, target_plan)
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
    
end