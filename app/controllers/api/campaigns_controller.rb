class Api::CampaignsController < ApplicationController
  
  respond_to :json
  before_filter :authenticate_user!
  
  def index
    render :json => current_user.campaigns.all
  end
  
  def create
    respond_with current_user.campaigns.create(params[:campaign]), :location => api_campaigns_path
  end
  
  def update
    if campaign = current_user.campaigns.find_by_id(params[:id])
      if campaign.update_attributes(params[:campaign])
        render :json => campaign
      else
        render :json => campaign.errors, :status => :unprocessable_entity
      end
    else
        render :json => {:errors => "Record Not Found"}
    end
  end
  
  def destroy
    if campaign = current_user.campaigns.find_by_id(params[:id])
      campaign.destroy
    end
    render :json => campaign
  end
end