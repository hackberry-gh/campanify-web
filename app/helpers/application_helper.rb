module ApplicationHelper
  def nav_class(route)
    controller, action = route.split("/")
    "active" if controller == params[:controller] && action == params[:action]
  end
end
