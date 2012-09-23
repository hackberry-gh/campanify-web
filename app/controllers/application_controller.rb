class ApplicationController < ActionController::Base
  protect_from_forgery
  
  helper_method :_layout
  
  def _layout
    (current_user && !current_user.new_record?) ? "application" : "welcome"
  end
end
