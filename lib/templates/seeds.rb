campaign = Campaign.create(name: "$name")
campaign.slug = "$slug"
campaign.save!
# campaign.setup if Rails.env.production?

admin = Administrator.create!(email: '$admin_email', full_name: "$admin_full_name", role: "root", password: "$admin_password", password_confirmation: "$admin_password")

user = User.create!(first_name: "John", last_name: "Doe", email: "johndoe@campanify.it")

home = Content::Page.create!(title: "Home", body: File.read("#{Rails.root}/db/seeds/pages/home.html"))
about = Content::Page.create!(title: "About", body: File.read("#{Rails.root}/db/seeds/pages/about.html"))
thank_you = Content::Page.create!(title: "Thank You", body: File.read("#{Rails.root}/db/seeds/pages/thank-you.html"))
user_form = Content::Widget.create!(title: "User Form", body: File.read("#{Rails.root}/db/seeds/widgets/user-form.html.erb"))
social_sharing = Content::Widget.create!(title: "Social Sharing", body: File.read("#{Rails.root}/db/seeds/widgets/social-sharing.html.erb"))
flexi_slider = Content::Widget.create!(title: "Flex Slider", body: File.read("#{Rails.root}/db/seeds/widgets/flex-slider.html.erb"))

home.widgets << user_form
thank_you.widgets << social_sharing
# don't add to widgets inline rendering
# about.widgets << flexi_slider

sample_post = Content::Post.new(title: "Sample Post", body: File.read("#{Rails.root}/db/seeds/posts/sample.md"))
sample_post.user = user
sample_post.save!

sample_event = Content::Event.create(
name: "Campanify Launch Party", description: "We are proud to launch our baby Campanify 1.0",
start_time: Time.now, location: "Whitecube Gallery", 
venue: {street: "Hoxton Square", city: "London", state: "England", zip: "N1 6PB", 
  country: "United Kingdom", latitude: "51.52725461288175", longitude: "-0.0813526878051789" },
privacy: "OPEN"  
)

# Load Translations
I18n.backend.backends[1].load_translations
translations = I18n.backend.backends[1].send(:translations)

translatebles = %(errors activerecord helpers flash devise views sharing html user_mailer language)

I18n.available_locales.each do |locale|      
  translations[:en].each do |key,value|
    if translatebles.include?(key.to_s.split(".").first)
      I18n.backend.store_translations(locale.to_s,{key => value}, :escape => false)
    end
  end
end

# Load Templates
Dir["#{Rails.root}/app/views/**/*"].delete_if{|f| !f.include?(".")}.each do |file|
  unless file.include?("admin")
    body = File.read(file)
    file_parts = file.split("/")
    path, format, handler = file_parts.last.split(".")
    partial = path.include?("_")
    file_parts.pop
    path = "#{file_parts.join("/")}/#{path}".gsub("#{Rails.root}/app/views/","")
    temp = Appearance::Template.create(:body => body, :format => format, 
                                :handler => handler, :locale => "en", 
                                :partial => partial, :path => path)                            
  end
end

# Load Assets
 Dir["#{Rails.root}/db/seeds/assets/**/*"].delete_if{|f| !f.include?(".")}.each do |file|

      body = File.read(file)
      file_parts = file.split("/")
      filename = file_parts.last
      content_type = Appearance::Asset::VALID_TYPES[file_parts.last.split(".").last.to_sym]
      asset = Appearance::Asset.create(:body => body, :content_type => content_type, :filename => filename)                            

  end