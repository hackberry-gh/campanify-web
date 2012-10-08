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
            "memcachier" => "dev",
            "newrelic" => "standard"
          },
          db: 'heroku-postgresql:dev',    
          campanify_fee: 0
        },
        town: {
          ps: {
            web: 1,
            worker: 1
          },
          addons: {
            "pgbackups" => "auto-week",
            "sendgrid" => "bronze",
            "memcachier" => "100",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:basic',     
          campanify_fee: 7000
        },
        city: {
          ps: {
            web: 2,
            worker: 1
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "silver",
            "memcachier" => "250",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:crane',
          campanify_fee: 14000
        },
        country: {
          ps: {
            web: 4,
            worker: 2
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "gold",
            "memcachier" => "500",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:kappa',
          campanify_fee: 28000
        },
        earth: {
          ps: {
            web: 8,
            worker: 4
          },
          addons: {
            "pgbackups" => "auto-week",            
            "sendgrid" => "platinum",
            "memcachier" => "1000",
            "newrelic" => "standard"            
          },
          db: 'heroku-postgresql:ronin',
          campanify_fee: 56000
        }
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
          
          # capistrano recipe to clone bare campaign app and setup on heroku
          capified = system("cap campanify:clone_app -s slug=#{slug} -s rails_root=#{Rails.root} -s campaign_name='#{campaign.name}' -s campaign_slug=#{slug} -s campaign_user_email=#{campaign.user.email} -s campaign_user_full_name='#{campaign.user.full_name}' -s campaign_user_password=#{Devise.friendly_token.first(6)} -s campaign_plan=#{campaign.plan} -s slug_underscore=#{slug.underscore}") 
          
          puts "=== CAPIFIED #{capified} ==="
          # return {error: "APP COULD NOT CREATED", campaign: campaign} unless capified
          
          # create s3 bucket per campaign
          AWS::S3::Base.establish_connection!(
            :access_key_id     => ENV['AWS_ACCESS_KEY_ID'],
            :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
            )
          AWS::S3::Bucket.create("campanify_app_#{slug.underscore}") 
          puts "=== S3 BUCKET CREATED ==="                 

          # .env to heroku config mapping
          file_name = "#{Rails.root}/lib/templates/env"
          content = File.read(file_name)
          content = content.gsub(/free/, campaign.plan)      
          content = content.gsub(/bucket/, "campanify_app_#{slug.underscore}")
          Hash[content.split("\n").map{|v| v.split("=")}].each do |k,v|
            heroku.put_config_vars(campaign.slug, k => v)                 
          end
          # maintenance and error pages
          heroku.put_config_vars(campaign.slug, "ERROR_PAGE_URL" => "http://static.campanify.it/errors/500.html") 
          heroku.put_config_vars(campaign.slug, "MAINTENANCE_PAGE_URL" => "http://static.campanify.it/errors/maintenance.html")                                               
          puts "=== APP CONFIG SETTED ON HEROKU ==="                  

          # capistrano recipe to create heroku postres db
          setup_db = system("cap campanify:setup_db -s slug=#{slug}")
          # return {error: "DB COULD NOT SETUP", campaign: campaign} unless setup_db
          puts "=== DB SET #{setup_db} ==="
          
          config = Plans.configuration(campaign.plan.to_sym)          
          config[:ps].each do |type, quantity|
            heroku.post_ps_scale(slug, type, quantity)
          end
          puts "=== SCALING DONE === "   
                 
          config[:addons].each do |addon, plan|
            begin      
              heroku.post_addon(slug, "#{addon}:#{plan}")
            rescue Exception => e
              puts e
            end
          end
          puts "=== ADDONS INSTALLED ==="                      

          # wait until sendgrid setup done
          until heroku.get_config_vars(slug).body["SENDGRID_USERNAME"].present? &&
                heroku.get_config_vars(slug).body["SENDGRID_PASSWORD"].present?
            sleep(1)
          end
          
          change_theme(campaign, "default")

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
          puts "ERROR ON CHANGE PLAN #{e}"
          rollback(campaign, target_plan)
          return {error: e, plan: target_plan, campaign: campaign}              
        end
      end
      
      def change_theme(campaign, theme)
        begin
          capified = system("cap campanify:change_theme -s slug=#{campaign.slug} -s theme=#{theme}")
        rescue Exception => e
          puts "ERROR ON CHANGE THEME #{e}"
          return {error: e, theme: theme, campaign: campaign}              
        end
      end
      
      private
      
      def migrate_db(campaign, target_plan)
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
        
        r = heroku.post_addon(campaign.slug, config[:db]) rescue nil
        r.body["message"].match(/\HEROKU_POSTGRESQL_+(.*)\_URL/)
        target_db = "HEROKU_POSTGRESQL_#{$1}_URL"
        puts "=== NEW DB ADDON CREATED ==="                            
        
        system("cap campanify:backup_db -s slug=#{campaign.slug}")
        puts "=== DB BACKUP CAPTURED ==="                                                       
        
        puts "=== WAITING FOR NEW DB ==="        
        waiting = system("cap campanify:wait_db -s slug=#{campaign.slug}")

        system("cap campanify:restore_db -s slug=#{campaign.slug} -s target_db=#{target_db}")
        puts "=== DB RESTORED ==="
        
        system("cap campanify:promote_db -s slug=#{campaign.slug} -s target_db=#{target_db}")          
        puts "=== DB PROMOTED ==="
        
        # remove old addon
        config_vars = heroku.get_config_vars(campaign.slug).body
        old_dbs = config_vars.clone.
                  delete_if{|key,value| !key.include?('POSTGRESQL')}.
                  delete_if{|key,value| value != config_vars['DATABASE_URL']}.
                  keys          
        old_dbs.each do |old_db|          
          heroku.delete_addon(campaign.slug, old_db) rescue nil
        end
        puts "=== OLD DB ADDON REMOVED ==="
        
        # turn maintenance mode off
        heroku.post_app_maintenance(campaign.slug, 0)
        campaign.set_status(Campaign::ONLINE)          
        puts "=== MAINTENANCE MODE OFF ==="
                
        return {campaign: campaign, target_plan: target_plan}
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
        system("cap campanify:backup_db -s slug=#{campaign.slug}")        
        puts "=== DB BACKUP CAPTURED ==="
        
        # remove next db addon
        heroku.delete_addon(campaign.slug, config[:db]) rescue nil
        puts "=== NEXT DB ADDON REMOVED ==="
        
        heroku.post_addon(campaign.slug, current_config[:db])
        puts "=== EXISTING DB ADDON CREATED ==="
        
        puts "=== WAITING FOR NEW DB ==="        
        system("cap campanify:wait_db -s slug=#{campaign.slug}")        
        
        # get new db url
        config_vars = heroku.get_config_vars(campaign.slug).body
        target_db = config_vars.clone.
                    delete_if{|key,value| !key.include?('POSTGRESQL')}.
                    delete_if{|key,value| value == config_vars['DATABASE_URL']}.
                    keys.first
        puts "=== DB URL COPIED ==="
        
        system("cap campanify:restore_db -s slug=#{campaign.slug} -s target_db=#{target_db}")
        puts "=== DB RESTORED ==="
        
        system("cap campanify:promote_db -s slug=#{campaign.slug} -s target_db=#{target_db}")        
        puts "=== DB PROMOTED ==="

        config_vars = heroku.get_config_vars(campaign.slug).body
        delete_dbs = config_vars.clone.
                    delete_if{|key,value| !key.include?('POSTGRESQL')}.
                    delete_if{|key,value| value == config_vars['DATABASE_URL']}.
                    keys
        delete_dbs.each do |db|            
          heroku.delete_addon(campaign.slug, db) rescue nil          
        end
        
        heroku.post_app_maintenance(campaign.slug, 0)
        campaign.set_status(Campaign::ONLINE)          
        puts "=== MAINTENANCE MODE OFF ==="
        puts "===*** ROLLED BACK ***==="          
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
      # system "rm -rf #{APPS_DIR}/#{slug}"
      system("cap campanify:remove_app -s slug=#{slug}")
      heroku.delete_app(slug) rescue nil
      AWS::S3::Base.establish_connection!(
        :access_key_id     => ENV['AWS_ACCESS_KEY_ID'],
        :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
        )
      AWS::S3::Bucket.delete("campanify_app_#{slug.underscore}", :force => true) rescue nil
    end
  end
  
  def change_plan(slug, target_plan)    
    if campaign = Campaign.find_by_slug(slug)
      result = Campaigns.change_plan(campaign, target_plan)
      unless result[:error]
        campaign.update_column(:plan, target_plan)
      else
        puts "=== SOMETING WENT WRONG SLUG:#{result[:campaign].slug} ERROR: #{result[:error]}==="  
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
        puts "=== SOMETING WENT WRONG, THEME COULDN'T CHANGED: #{result[:campaign].slug} ERROR: #{result[:error]} ==="        
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