module Campanify

  module Heroku
    extend ActiveSupport::Concern
    def heroku
      @heroku ||= ::Heroku::API.new
    end
  end
  
  module GoogleStorageClient

    class << self
      def storage
        @storage ||= Fog::Storage.new(
          :provider => "Google",
          :google_storage_access_key_id  => ENV['GOOGLE_STORAGE_ACCESS_KEY_ID'],
          :google_storage_secret_access_key => ENV['GOOGLE_STORAGE_SECRET_ACCESS_KEY']
        )
      end
      def create_bucket(name)
        storage.put_bucket(name)
      end
      def delete_bucket(name)
        storage.directories.keep_if{|d| d.key == name}.first.files.each{|f| f.destroy }
        storage.delete_bucket(name)
      end
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
            "memcachier" => "dev",
            "newrelic" => "standard"
          },
          db: 'heroku-postgresql:dev',    
          support: 0
        },
        town: {
          ps: {
            web: 2,
            worker: 0
          },
          addons: {
            "pgbackups" => "auto-week",
            "sendgrid" => "bronze",
            "memcachier" => "dev",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:basic',     
          support: 1
        },
        city: {
          ps: {
            web: 3,
            worker: 1
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "silver",
            "memcachier" => "100",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:crane',
          support: 1
        },
        country: {
          ps: {
            web: 4,
            worker: 2
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "gold",
            "memcachier" => "250",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:kappa',
          support: 3
        },
        earth: {
          ps: {
            web: 8,
            worker: 4
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "platinum",
            "memcachier" => "500",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:ronin',
          support: 7
        }
      }[plan]
      end
    end
  end
  
  module Campaigns
    class << self
      
      include Heroku 
      include GoogleStorageClient       
      
      def create_app(campaign)  
        puts "=== APP CREATION STARTED AT #{Time.now} ===".green
        app = heroku.post_app(name: campaign.slug).body
        slug = app["name"]                
        return {error: app["error"], campaign: campaign} if app["error"]
        
        puts "=== APP CREATED #{slug} ===".green     
           
        begin
          app_dir = "#{APPS_DIR}/#{slug}"
          
          # create bucket per campaign
          
          GoogleStorageClient.create_bucket("campanify-app-#{slug}") 
          puts "=== BUCKET CREATED ===".green                 

          # .env to heroku config mapping
          file_name = "#{Rails.root}/lib/templates/env"
          content = File.read(file_name)
          content = content.gsub(/free/, campaign.plan)      
          content = content.gsub(/bucket/, "campanify-app-#{slug}")
          Hash[content.split("\n").map{|v| v.split("=")}].each do |k,v|
            heroku.put_config_vars(slug, k => v)                 
          end
          # maintenance and error pages
          # heroku.put_config_vars(slug, "ERROR_PAGE_URL" => "http://static.campanify.it/errors/500.html") 
          # heroku.put_config_vars(slug, "MAINTENANCE_PAGE_URL" => "http://static.campanify.it/errors/maintenance.html")                                               
          puts "=== APP CONFIG SETTED ON HEROKU ===".green
          puts heroku.get_config_vars(slug).body
          puts "==================================="
          
          # capistrano recipe to clone bare campaign app and setup on heroku
          admin_password = Devise.friendly_token.first(6)
          capified = system("cap campanify:clone_app -s slug=#{slug} -s rails_root=#{Rails.root} -s campaign_name='#{campaign.name}' -s campaign_slug=#{slug} -s campaign_user_email=#{campaign.user.email} -s campaign_user_full_name='#{campaign.user.full_name}' -s campaign_user_password=#{admin_password} -s campaign_plan=#{campaign.plan} -s slug_underscore=#{slug.underscore}") 
          
          return {error: "CAP FAILED, campanify:clone_app", campaign: campaign} unless capified
          puts "=== CAPIFIED #{capified} ===".green

          enable_env = system("cap campanify:enable_env_compile -s slug=#{slug}")
          return {error: "ENABLE ENV FAILED, campanify:enable_env_compile", campaign: campaign} unless enable_env
          puts "=== ENV ENABLED #{enable_env} ===".green

          # capistrano recipe to create heroku postres db
          setup_db = system("cap campanify:setup_db -s slug=#{slug}")
          return {error: "CAP FAILED, campanify:setup_db", campaign: campaign} unless setup_db          
          puts "=== DB SET #{setup_db} ===".green          
          
          config = Plans.configuration(campaign.plan.to_sym)          
          config[:ps].each do |type, quantity|
            heroku.post_ps_scale(slug, type, quantity)
          end
          puts "=== SCALING DONE === " .green  
                 
          config[:addons].each do |addon, plan|
            begin      
              heroku.post_addon(slug, "#{addon}:#{plan}")
            rescue Exception => e
              puts e.inspect.to_s.red
            end
          end
          puts "=== ADDONS INSTALLED ==="                      

          # wait until sendgrid setup done
          until heroku.get_config_vars(slug).body["SENDGRID_USERNAME"].present? &&
                heroku.get_config_vars(slug).body["SENDGRID_PASSWORD"].present?
            sleep(1)
          end
          
          theme_changed = change_theme(campaign, "default")
          return theme_changed if theme_changed[:error]

          puts "=== APP CREATION FINISHED AT #{Time.now} ===".green                  
          
          if campaign.plan != "free"
            migrate_db(campaign, campaign.plan)
          end
          
          Notification.delay.new_campaign(campaign, admin_password)
          
          return {campaign: campaign}
        rescue Exception => e
          return {error: e, campaign: campaign}
        end
      end
      
      def change_plan(campaign, target_plan)
        begin
          campaign.migration_steps = []
          # get config of plan
          current_config = Plans.configuration(campaign.plan.to_sym)
          target_config = Plans.configuration(target_plan.to_sym)
          
          # scale
          target_config[:ps].each { |type, quantity| heroku.post_ps_scale(campaign.slug, type, quantity) }
          puts "=== SCALED ===".green
          campaign.migration_steps << "ps"

          # updgrade/downgrade addons
          target_config[:addons].each { |addon, plan| heroku.put_addon(campaign.slug, "#{addon}:#{plan}") rescue nil }
          puts "=== ADDONS DONE ===".green  
          campaign.migration_steps << "addons"

          migrate_db(campaign, target_plan)
          puts "=== DB MIGRATION DONE ===".green    
          campaign.migration_steps << "db"     

          # change plan environment var
          heroku.put_config_vars(campaign.slug, 'PLAN' => target_plan)     
          puts "=== ENVIRONMENT CHANGED ===".green 
          campaign.migration_steps << "plan"       
        
          return {plan: target_plan, campaign: campaign}                          
        rescue Exception => e
          puts "ERROR ON CHANGE PLAN #{e}".red
          rollback(campaign, target_plan)
          return {error: e, plan: target_plan, campaign: campaign}              
        end
      end
      
      def change_theme(campaign, theme)
        begin
          capified = system("cap campanify:change_theme -s slug=#{campaign.slug} -s theme=#{theme}")
          return {error: "CAP FAILED, campanify:change_theme", campaign: campaign} unless capified          
          return {campaign: campaign}
        rescue Exception => e
          puts "ERROR ON CHANGE THEME #{e}".red
          return {error: e, theme: theme, campaign: campaign}              
        end
      end
      
      private
      
      def migrate_db(campaign, target_plan)
        puts "=== HEROKU POSTGRES MIGRATION STARTED AT #{Time.now} ===".green                            
        # get configs
        current_config = Campanify::Plans.configuration(campaign.plan.to_sym)
        target_config = Campanify::Plans.configuration(target_plan.to_sym)       
        
        # put app on maintenance mode
        heroku.post_app_maintenance(campaign.slug, 1)
        campaign.set_status(Campaign::MAINTENANCE)
        puts "=== MAINTENANCE MODE ON ===".green
        campaign.migration_steps << "maintenance_on"                            
        
        # db migration
        # ============
        
        target_db_response = heroku.post_addon(campaign.slug, target_config[:db])
        target_db_response.body["message"].match(/\HEROKU_POSTGRESQL_+(.*)\_URL/)
        target_db_url = "HEROKU_POSTGRESQL_#{$1}_URL"
        puts "=== NEW DB ADDON CREATED ===".green     
        campaign.migration_steps << "addon_db"                        
        
        backup = system("cap campanify:backup_db -s slug=#{campaign.slug}")                                                       
        raise "campanify:backup_db failed" unless backup
        puts "=== DB BACKUP CAPTURED: #{backup}===".green   
        campaign.migration_steps << "backup_db"       
             
        waiting = system("cap campanify:wait_db -s slug=#{campaign.slug}")           
        raise "campanify:wait_db failed" unless waiting        
        puts "=== WAITING FOR NEW DB: #{waiting} ===".green
        campaign.migration_steps << "wait_db"         

        restore = system("cap campanify:restore_db -s slug=#{campaign.slug} -s target_db=#{target_db_url}")
        raise "campanify:restore_db failed" unless restore                
        puts "=== DB RESTORED: #{restore} ===".green   
        campaign.migration_steps << "restore_db"     
        
        promote = system("cap campanify:promote_db -s slug=#{campaign.slug} -s target_db=#{target_db_url}")          
        raise "campanify:promote_db failed" unless promote        
        puts "=== DB PROMOTED: #{promote} ===".green 
        campaign.migration_steps << "promote_db"        
        
        heroku.delete_addon(campaign.slug, current_config[:db])
        puts "=== OLD DB ADDON REMOVED ===".green
        campaign.migration_steps << "remove_db"
        
        # turn maintenance mode off
        heroku.post_app_maintenance(campaign.slug, 0)         
        puts "=== MAINTENANCE MODE OFF ===".green
        campaign.migration_steps << "maintenance_off"
                
        return {campaign: campaign, target_plan: target_plan}
      end
      
      def rollback(campaign, target_plan)
        puts "===*** ROLLING BACK ***===".yellow  
        
        current_config = Campanify::Plans.configuration(campaign.plan.to_sym)
        target_config = Campanify::Plans.configuration(target_plan.to_sym)
        
        # scale
        if campaign.migration_steps.include?("ps")             
          current_config[:ps].each { |type, quantity| heroku.post_ps_scale(campaign.slug, type, quantity) }
           puts "===*** PS ROLLED BACK ***===".yellow
        end
        
        # updgrade/downgrade addons
        if campaign.migration_steps.include?("addons")                     
          current_config[:addons].each { |addon, plan| heroku.put_addon(campaign.slug, "#{addon}:#{plan}") rescue nil}
           puts "===*** ADDONS ROLLED BACK ***===".yellow          
        end
        
        # capture backup of current db
        if campaign.migration_steps.include?("promote_db")
          cap = system("cap campanify:backup_db -s slug=#{campaign.slug}")        
          puts "===*** DB BACKUP CAPTURED: #{cap} ***===".yellow
        end
        
        # remove next db addon
        if campaign.migration_steps.include?("addon_db")                     
          heroku.delete_addon(campaign.slug, target_config[:db]) rescue nil
          puts "===*** TARGET DB ADDON REMOVED ***===".yellow
        end
        
        if campaign.migration_steps.include?("remove_db") 
          old_db_response = heroku.post_addon(campaign.slug, current_config[:db])
          old_db_response.body["message"].match(/\HEROKU_POSTGRESQL_+(.*)\_URL/)
          old_db_url = "HEROKU_POSTGRESQL_#{$1}_URL"
          puts "===*** OLD DB ADDON CREATED ***===".yellow
        
          cap = system("cap campanify:wait_db -s slug=#{campaign.slug}")        
          puts "===*** WAITING FOR OLD DB: #{cap} ***===".yellow  
        
          cap = system("cap campanify:restore_db -s slug=#{campaign.slug} -s target_db=#{old_db_url}")
          puts "===*** OLD DB RESTORED: #{cap} ***===".yellow
          
          cap = system("cap campanify:promote_db -s slug=#{campaign.slug} -s target_db=#{old_db_url}")        
          puts "===*** OLD DB PROMOTED #{cap} ***===".yellow
        end
        
        heroku.post_app_maintenance(campaign.slug, 0)
        campaign.set_status(Campaign::ONLINE)    
        puts "===*** MAINTENANCE MODE OFF ***===".yellow
        puts "===*** ROLLED BACK ***===".yellow          
      end
    end
    
  end
  
  extend ActiveSupport::Concern
  include Heroku
  include GoogleStorageClient  
  
  def create_app(slug)
    if campaign = Campaign.find_by_slug(slug)
      result = Campaigns.create_app(campaign)
      if result[:error]
        puts "=== SOMETHING WENT WRONG, DESTROYING APP SLUG: #{result[:campaign].slug} ERROR: #{result[:error]} ===".red
        campaign.destroy
        Notification.new_campaign_failed(campaign).deliver
      else
        user = result.delete(:user)
        campaign.set_status(Campaign::ONLINE)
      end
      result
    end
  end
  
  def destroy_app(slug)
    if slug
      # system "rm -rf #{APPS_DIR}/#{slug}"
      system("cap campanify:remove_app -s slug=#{slug}")
      heroku.delete_app(slug) rescue nil
      GoogleStorageClient.delete_bucket("campanify-app-#{slug}")  rescue nil  
    end
  end
  
  def change_plan(slug, target_plan)    
    if campaign = Campaign.find_by_slug(slug)
      result = Campaigns.change_plan(campaign, target_plan)
      unless result[:error]
        campaign.update_column(:plan, target_plan)
        campaign.set_status(Campaign::ONLINE)         
      else
        puts "=== SOMETHING WENT WRONG, PLAN COULDN'T CHANGED: SLUG:#{result[:campaign].slug} ERROR: #{result[:error]}===".red  
      end
      result
    end
  end
  
  def change_theme(slug, theme)
    if campaign = Campaign.find_by_slug(slug)
      result = Campaigns.change_theme(campaign, theme)
      unless result[:error]
        campaign.update_column(:theme, theme)
        campaign.set_status(Campaign::ONLINE)
      else
        puts "=== SOMETHING WENT WRONG, THEME COULDN'T CHANGED: SLUG:#{result[:campaign].slug} ERROR: #{result[:error]} ===".red        
      end
      result
    end
  end
  
  def create_user(email, full_name)
    password = ::Devise.friendly_token.first(6)
    user = User.create(email: email, full_name: full_name, password: password, password_confirmation: password)
    if user.persisted?
      user
    else
      false
    end  
  end
    
end