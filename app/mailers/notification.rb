class Notification < ActionMailer::Base
  default from: "no-reply@campanify.it"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notification.new_campaign.subject
  #
  def new_user(user)
    @user = user    
    mail to: user.email
  end
  
  def new_campaign(campaign, admin_password)
    @campaign = campaign
    @admin_password = admin_password

    mail to: campaign.user.email
  end
  
  def new_campaign_fail(campaign)
    @campaign = campaign    
    mail to: campaign.user.email, cc: "tech@campanify.it"    
  end
end
