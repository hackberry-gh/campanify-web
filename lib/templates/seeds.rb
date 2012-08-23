campaign = Campaign.create(name: "$name")
campaign.slug = "$slug"
campaign.save!
campaign.setup if Rails.env.production?

admin = Administrator.create!(email: '$admin_email', full_name: "$admin_full_name", role: "root")
admin.password = "$admin_password"
admin.password_confirmation = "$admin_password"
admin.save!

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