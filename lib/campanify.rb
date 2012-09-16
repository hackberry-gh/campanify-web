# require 'heroku_api'
# require 'rake'

module Campanify

  module Heroku
    extend ActiveSupport::Concern
    def heroku
      @heroku ||= ::Heroku::API.new
    end
  end
  
  module Plans
    class << self
      def all
        %w(free town city country earth)
      end
      def configuration(plan)
      {
        free: {
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
        town: {
          ps: {
            web: 1,
            worker: 1
          },
          addons: {
            "pgbackups" => "auto-week",
            "sendgrid" => "bronze",
            "memcachier" => "100"
          },
          db: 'heroku-postgresql:basic',          
          price: 139 # 70 + 35 + 9.95 + 15 + 9 = 138.95
        },
        city: {
          ps: {
            web: 2,
            worker: 1
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "silver",
            "memcachier" => "250"
          },
          db: 'heroku-postgresql:crane',
          price: 369 # 140 + 70 + 79.95 + 25 + 50 = 364.95
        },
        country: {
          ps: {
            web: 4,
            worker: 2
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "gold",
            "memcachier" => "500"
          },
          db: 'heroku-postgresql:kappa',
          price: 799 # 280 + 175 + 199.95 + 40 + 100 = 794.95
        },
        earth: {
          ps: {
            web: 8,
            worker: 4
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "platinum",
            "memcachier" => "1000"
          },
          db: 'heroku-postgresql:ronin',
          price: 1619 # 560 + 385 + 399.95 + 70 + 200 = 1614.95
        },
        # universal: {
        #           ps: {
        #             web: 12,
        #             worker: 4
        #           },
        #           addons: {
        #             "pgbackups" => "auto-week",            
        #             "sendgrid" => "enterprise",
        #             "memcachier" => "2500"
        #           },
        #           db: 'heroku-postgresql:fugu',
        #           price: #1120 + 525 + ? + 165 + 400
        #         }
      }[plan]
      end
    end
  end
  
  module Campaigns
    class << self
      
      include Heroku      
      
      def create_app(campaign)  
        puts "=== APP CREATION STARTED AT #{Time.now} ==="
        app = heroku.post_app(name: campaign.slug).body
        slug = app["name"]                
        return {error: app["error"], campaign: campaign} unless slug
        
        puts "=== APP CREATED #{slug} ==="        
        begin
          app_dir = "#{APPS_DIR}/#{slug}"

          mkdir = system("mkdir #{app_dir}")
          return {error: "APP DIR COULD NOT CREATED", campaign: campaign} unless mkdir
          puts "=== APP DIR CREATED ==="        
          
          # heroku accounts:set
          system('git config heroku.account campanify_tech')
          system("git config remote.heroku.url git@heroku.campanify_tech:#{slug}.git")
          puts "=== HEROKU ACCOUNT SET ==="                  
          
          clone = system("git clone git@heroku.campanify_tech:campanify-app.git #{app_dir} -o heroku")
          return {error: "GIT REPO COULD NOT CLONNED", campaign: campaign} unless clone
          puts "=== GIT REPO CLONNED ==="                  

          file_name = "#{Rails.root}/lib/templates/seeds.rb"
          content = File.read(file_name)
          content = content.gsub(/\$name/, campaign.name)
          content = content.gsub(/\$slug/, campaign.slug)
          content = content.gsub(/\$admin_email/, campaign.user.email)
          content = content.gsub(/\$admin_full_name/, campaign.user.full_name)        
          content = content.gsub(/\$admin_password/, Devise.friendly_token.first(6))            
          target_file_name = "#{app_dir}/db/seeds.rb"
          system("touch #{target_file_name}")
          File.open(target_file_name, "w") {|file| file.write content}
          puts "=== SEED.RB GENERATED ==="                  

          file_name = "#{Rails.root}/lib/templates/install.sh"
          content = File.read(file_name)
          content = content.gsub(/\$app_dir/, app_dir)      
          content = content.gsub(/\$name/, campaign.name)
          content = content.gsub(/\$slug/, campaign.slug)
          target_file_name = "#{app_dir}/install.sh"
          system("touch #{target_file_name}")      
          File.open(target_file_name, "w") {|file| file.write content}
          puts "=== INSTALL.SH GENERATED ==="                  
          
          file_name = "#{app_dir}/config/settings.yml"
          content = File.read(file_name)
          content = content.gsub(/localhost:3000/, "#{slug}.campanify.it")      
          content = content.gsub("host_type: filesystem", "host_type: s3")            
          content = content.gsub("storage: file", "storage: fog")                  
          target_file_name = file_name
          File.open(target_file_name, "w") {|file| file.write content}
          puts "=== SETTINGS.YML GENERATED ==="                  

          file_name = "#{app_dir}/.env"
          content = File.read(file_name)
          content = content.gsub(/free/, campaign.plan)      
          content = content.gsub(/bucket/, "campanify_app_#{slug.underscore}")                
          target_file_name = file_name
          File.open(target_file_name, "w") {|file| file.write content}      
          puts "=== .ENV GENERATED ==="      
          
          AWS::S3::Base.establish_connection!(
            :access_key_id     => ENV['AWS_S3_KEY'],
            :secret_access_key => ENV['AWS_S3_SECRET']
            )
          AWS::S3::Bucket.create("campanify_app_#{slug.underscore}") 
          puts "=== S3 BUCKET CREATED ==="                 

          chmod = system("cd #{app_dir} && chmod +x install.sh")
          return {error: "INSTALL SCRIPT COULD NOT COPIED", campaign: campaign} unless chmod

          # rake = system("cd #{app_dir} && bundle exec rake campanify:setup")
          # return {error: app["name"]} unless rake 

          current_dir = Dir.pwd
          Dir.chdir(app_dir)
          install = system("cd #{app_dir} && ./install.sh")
          return {error: "APP COULD NOT INSTALLED", campaign: campaign} unless install
          Dir.chdir(current_dir)  
          puts "=== APP INSTALLED ==="                                    

          # rm = system("cd #{app_dir} && rm -rf install.sh")
          #       return {error: app["name"]} unless rm

          Hash[File.open("#{app_dir}/.env").read.split("\n").map{|v| v.split("=")}].each do |k,v|
            system("cd #{app_dir} && bundle exec heroku config:add #{k}=#{v} --app #{slug}")
          end
          puts "=== APP CONFIG SETTED ON HEROKU ==="                  

          system("cd #{app_dir} && bundle exec heroku run rake db:migrate --app #{slug} --trace")
          puts "=== DB MIGRATED ON HEROKU ==="                  
                    
          system("cd #{app_dir} && bundle exec heroku run rake db:seed --app #{slug} --trace")
          puts "=== DB SEEDED ON HEROKU ==="                            

          puts "=== HEROKU SETUP STARTED ==="
          # require 'rake'
          config = Plans.configuration(campaign.plan.to_sym)          
          # scale
          puts "=== SCALING === "
          config[:ps].each do |type, quantity|
            heroku.post_ps_scale(slug, type, quantity)
          end
          # updgrade/downgrade addons
          puts "=== INSTALLING ADDONS ==="            
          config[:addons].each do |addon, plan|
            begin      
              heroku.post_addon(slug, "#{addon}:#{plan}")
            rescue Exception => e
              puts e
            end
          end

          # wait until sendgrid setup done
          until heroku.get_config_vars(slug).body["SENDGRID_USERNAME"].present? &&
                heroku.get_config_vars(slug).body["SENDGRID_PASSWORD"].present?
            sleep(1)
          end

          puts "=== CONFIG ==="
          puts heroku.get_config_vars(slug).body

          puts "=== APP CREATION FINISHED AT #{Time.now} ==="                  
          
          if campaign.plan != "free"
            migrate_db(campaign, campaign.plan)
          end
          
          return {campaign: campaign}
        rescue Exception => e
          return {error: e, campaign: campaign}
        end
      end
      
      def change_plan(campaign, target_plan)
        begin
          # get config of plan
          current_config = Plans.configuration(campaign.plan.to_sym)
          config = Plans.configuration(target_plan.to_sym)
          puts "=== CONFIGS SET ==="
          
          # scale
          config[:ps].each { |type, quantity| heroku.post_ps_scale(campaign.slug, type, quantity) }
          puts "=== SCALED ==="

          # updgrade/downgrade addons
          config[:addons].each { |addon, plan| heroku.put_addon(campaign.slug, "#{addon}:#{plan}") rescue nil }
          puts "=== ADDONS DONE ==="          

          migrate_db(campaign, target_plan)
          puts "=== DB MIGRATION DONE ==="          

          # change plan environment var
          heroku.put_config_vars(campaign.slug, 'PLAN' => target_plan)     
          puts "=== ENVIRONMENT CHANGED ==="        
        
          return {plan: target_plan, campaign: campaign}                          
        rescue Exception => e
          # rollback
          puts "ERROR #{e}"
          rollback(campaign, target_plan)
          return {error: e, plan: target_plan, campaign: campaign}              
        end
      end
      
      private
      
      def migrate_db(campaign, target_plan)
        # begin
          puts "=== HEROKU POSTGRES MIGRATION STARTED AT #{Time.now} ==="                            
          # get configs
          current_config = Campanify::Plans.configuration(campaign.plan.to_sym)
          config = Campanify::Plans.configuration(target_plan.to_sym)
          puts "=== CONFIGS SET ==="                            
          
          # put app on maintenance mode
          heroku.post_app_maintenance(campaign.slug, 1)
          campaign.set_status(Campaign::MAINTENANCE)
          puts "=== MAINTENANCE MODE ON ==="                            
          
          # db migration
          # ============

          # add new db addon
          heroku.delete_addon(campaign.slug, config[:db]) rescue nil
          # puts "=== EXISTING DB ADDON REMOVED ==="                            
          
          heroku.post_addon(campaign.slug, config[:db]) rescue nil
          puts "=== NEW DB ADDON CREATED ==="                            
          
          # capture backup of current db
          system("heroku pgbackups:capture --expire --app #{campaign.slug}")
          puts "=== DB BACKUP CAPTURED ==="                            
          
          # get new db url
          config_vars = heroku.get_config_vars(campaign.slug).body
          target_db = config_vars.
                      delete_if{|key,value| !key.include?('POSTGRESQL')}.
                      delete_if{|key,value| value == config_vars['DATABASE_URL']}.
                      keys.first
          puts "=== DB URL COPIED ==="                            
          
          # TODO: wait for ready
          waiting = `heroku pg:wait --app #{campaign.slug}`
          puts "=== WAITING FOR NEW DB: #{waiting} ==="

          # restore new db from backup
          system("heroku pgbackups:restore #{target_db} --app #{campaign.slug} --confirm #{campaign.slug}")
          puts "=== DB RESTORED ==="
          
          # promote new db
          system("heroku pg:promote #{target_db} --app #{campaign.slug}")
          puts "=== DB PROMOTED ==="
          
          # remove old db addon
          heroku.delete_addon(campaign.slug, current_config[:db]) rescue nil
          puts "=== OLD DB ADDON REMOVED ==="
          
          # remove app from maintenance mode
          heroku.post_app_maintenance(campaign.slug, 0)
          campaign.set_status(Campaign::ONLINE)          
          puts "=== MAINTENANCE MODE OFF ==="
                  
          return {campaign: campaign, target_plan: target_plan}
        # rescue Exception => e
        #           # rollback
        #           rollback(campaign, target_plan)
        #           
        #           return {error: e, campaign: campaign, target_plan: target_plan}
        #         end
      end
      
      def rollback(campaign, target_plan)
        puts "===*** ROLLING BACK ***==="        
        current_config = Campanify::Plans.configuration(campaign.plan.to_sym)
        config = Campanify::Plans.configuration(target_plan.to_sym)
        puts "=== CONFIGS SET ==="
        
        # scale
        current_config[:ps].each { |type, quantity| heroku.post_ps_scale(campaign.slug, type, quantity) }

        # updgrade/downgrade addons
        current_config[:addons].each { |addon, plan| heroku.put_addon(campaign.slug, "#{addon}:#{plan}") rescue nil}
        
        # capture backup of current db
        system("heroku pgbackups:capture --expire --app #{campaign.slug}")
        puts "=== DB BACKUP CAPTURED ==="
        
        # remove next db addon
        heroku.delete_addon(campaign.slug, config[:db]) rescue nil
        puts "=== NEXT DB ADDON REMOVED ==="
        
        heroku.post_addon(campaign.slug, current_config[:db])
        puts "=== EXISTING DB ADDON CREATED ==="
        
        # TODO: wait for ready
        waiting = `heroku pg:wait --app #{campaign.slug}`
        puts "=== WAITING FOR NEW DB: #{waiting} ==="
        
        # get new db url
        config_vars = heroku.get_config_vars(campaign.slug).body
        target_db = config_vars.
                    delete_if{|key,value| !key.include?('POSTGRESQL')}.
                    delete_if{|key,value| value == config_vars['DATABASE_URL']}.
                    keys.first
        puts "=== DB URL COPIED ==="
        
        # restore new db from backup
        system("heroku pgbackups:restore #{target_db} --app #{campaign.slug} --confirm #{campaign.slug}")
        puts "=== DB RESTORED ==="
        
        # promote new db
        system("heroku pg:promote #{target_db} --app #{campaign.slug}")
        puts "=== DB PROMOTED ==="
        
        # remove app from maintenance mode
        heroku.post_app_maintenance(campaign.slug, 0)
        campaign.set_status(Campaign::ONLINE)          
        puts "=== MAINTENANCE MODE OFF ==="
        
      end
    end
    
  end
  
  extend ActiveSupport::Concern
  include Heroku
  
  def create_app(slug)
    if campaign = Campaign.find_by_slug(slug)
      result = Campaigns.create_app(campaign)
      if result[:error]
        puts "=== SOMETING WENT WRONG, DESTROYING APP SLUG: #{result[:campaign].slug} ERROR: #{result[:error]} ==="
        campaign.destroy
      else
        user = result.delete(:user)
        campaign.set_status(Campaign::ONLINE)
      end
      result
    end
  end
  
  def destroy_app(slug)
    if slug
      system "rm -rf #{APPS_DIR}/#{slug}"
      heroku.delete_app(slug) rescue nil
      AWS::S3::Base.establish_connection!(
          :access_key_id     => ENV['AWS_S3_KEY'],
          :secret_access_key => ENV['AWS_S3_SECRET']
        )
      AWS::S3::Bucket.delete("campanify_app_#{slug.underscore}", :force => true) rescue nil
    end
  end
  
  def change_plan(slug, target_plan)    
    if campaign = Campaign.find_by_slug(slug)
      result = Campaigns.change_plan(campaign, target_plan)
      unless result[:error]
        campaign = campaign.update_column(:plan, target_plan)
      else
        puts "=== SOMETING WENT WRONG SLUG:#{result[:campaign].slug} ERROR: #{result[:error]}==="  
      end
      result
    end
  end
  
  def create_user(email, full_name)
    password = ::Devise.friendly_token.first(6)
    user = User.create(email: email, full_name: full_name, password: password, password_confirmation: password)
    if user.persisted?
      user.send_reset_password_instructions
      user
    else
      false
    end  
  end
    
end