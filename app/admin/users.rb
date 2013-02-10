ActiveAdmin.register User do
  index do
    selectable_column
    column :full_name
    column :email
    column :current_sign_in_at    
    column :last_sign_in_at       
    column :created_at
    column :level
    default_actions 
  end
  form do |f|
    f.inputs do
        f.input :email
        f.input :full_name
        f.input :level
    end
    f.buttons
  end
end
