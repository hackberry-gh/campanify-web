include Campanify    
class Api::CampaignsController < ApplicationController
  
  def create
    if params[:name] && params[:plan]
      result = create_app(params[:name],params[:plan]) 
    else
      result = {:error => "missing arguments"}
    end
    render :json => result
  end
  
  def update
    if params[:action] == "migrate_db" && params[:slug] && params[:current_plan] && params[:next_plan]
      result = migrate_db(params[:slug],params[:current_plan],params[:next_plan])
    else
      result = {:error => "missing arguments"}
    end
    render :json => result
  end
end