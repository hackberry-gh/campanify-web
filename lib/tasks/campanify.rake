namespace :campanify do
  desc "Creates an App with given name"
  task :create_app, [:name, :plan] => :environment do |t, args|
    include Campanify    
    safe_create(args[:name],args[:plan])
  end
  desc "Migrates db"  
  task :migrate_db, [:slug, :current_plan, :next_plan] => :environment do |t, args|
    include Campanify    
    migrate_db(args[:slug],args[:current_plan],args[:next_plan])
  end
end