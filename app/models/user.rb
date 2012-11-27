class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, 
         :token_authenticatable

  attr_accessible :email, :password, :password_confirmation, :remember_me,
                  :full_name, :level
  has_many        :campaigns
  after_create    :reset_authentication_token!                
  after_create    :send_reset_password_instructions
end
