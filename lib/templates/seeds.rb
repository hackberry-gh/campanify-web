campaign = Campaign.create(name: "$name")
campaign.slug = "$slug"
campaign.save!
# campaign.setup if Rails.env.production?

admin = Administrator.create!(email: '$admin_email', full_name: "$admin_full_name", role: "root", password: "$admin_password", password_confirmation: "$admin_password")