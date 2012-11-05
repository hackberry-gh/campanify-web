include Campanify::Heroku
    
class PagesController < ApplicationController
  def index
  end
  
  def show
    redirect_to "/404" and return unless File.exists?("#{Rails.root}/app/views/pages/_#{params[:id]}.html.erb")
    render layout: false if request.xhr?
  end
  
  def addons
    
    unless @addons = Rails.cache.read("heroku_addons")
      @addons = heroku.get_addons.body
      Rails.cache.write("heroku_addons", @addons, :expires_in => 5.minutes)
    end 
       
    render :json => @addons
    
  end
end
