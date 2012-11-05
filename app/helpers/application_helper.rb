module ApplicationHelper
  def nav_class(route)
    controller, action = route.split("/")
    "active" if controller == params[:controller] && action == params[:action]
  end
  def plans_for_select
    if current_user && current_user.level > 0
      Campanify::Plans.all
    else
      Campanify::Plans.all.delete_if{|p| p != "free"}
    end
  end
end
