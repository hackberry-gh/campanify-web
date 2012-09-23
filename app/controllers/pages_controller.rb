class PagesController < ApplicationController
  def index
    render layout: _layout
  end
  
  def show
    redirect_to "/404" and return unless File.exists?("#{Rails.root}/app/views/pages/_#{params[:id]}.html.erb")
    render layout: false if request.xhr?
  end
end
