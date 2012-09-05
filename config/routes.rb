CampanifyWeb::Application.routes.draw do
  devise_for :users

  match "/api/campaigns/create" => "api/campaigns#create"
  match "/api/campaigns/update" => "api/campaigns#update"  
  
end
