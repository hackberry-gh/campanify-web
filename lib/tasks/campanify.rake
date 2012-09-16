namespace :campanify do  
  desc "Creates an App with given name, plan behalf of Campanify Admin"
  task :create_app, [:name, :plan] => :environment do |t, args|
    include Campanify    
    create_app(args[:name],args[:plan])
  end
  task :destroy_app, [:slug] => :environment do |t, args|
    include Campanify    
    destroy_app(args[:slug])
  end
  # desc "Migrates db with given slug, current and next plan"  
  # task :migrate_db, [:slug, :current_plan, :next_plan] => :environment do |t, args|
  #   include Campanify    
  #   migrate_db(args[:slug],args[:current_plan],args[:next_plan])
  # end
  desc "Change plan given slug and target plan"  
  task :change_plan, [:slug, :next_plan] => :environment do |t, args|
    include Campanify    
    change_plan(args[:slug],args[:next_plan])
  end
  desc "Creates new User with given name and email"  
  task :create_user, [:email, :full_name] => :environment do |t, args|
    include Campanify    
    create_user(args[:email], args[:full_name])
  end 
  desc "Creates an App with given name, plan behalf of Campanify Admin [Async Job]"
  task :create_app_async, [:name, :plan] => :environment do |t, args|
    Delayed::Job.enqueue Jobs::CreateApp.new(args[:name],args[:plan],Campanify::ADMIN)
  end 
  # desc "Migrates db with given slug, current and next plan [Async Job]"
  # task :migrate_db_async, [:slug, :current_plan, :next_plan] => :environment do |t, args|
  #   Delayed::Job.enqueue Jobs::MigrateDb.new(args[:slug],args[:current_plan],args[:next_plan])
  # end  
  desc "Change plan given slug and target plan [Async Job]"
  task :change_plan, [:slug, :next_plan] => :environment do |t, args|
    Delayed::Job.enqueue Jobs::ChangePlan.new(args[:slug],args[:next_plan])
  end  
end