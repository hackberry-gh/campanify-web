class Notification < ActionMailer::Base
  default from: "no-reply@campanify.it"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.notification.new_campaign.subject
  #
  def new_campaign(campaign, admin_password)
    @campaign = campaign
    @admin_password = admin_password

    mail to: campaign.user.email
  end
end
