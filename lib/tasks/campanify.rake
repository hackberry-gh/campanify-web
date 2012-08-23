namespace :campanify do
  desc "Creates an App with given name"
  task :create_app, [:name] => :environment do |t, args|
    include Campanify
    safe_create(args[:name])
  end
end