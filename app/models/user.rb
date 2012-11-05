class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, 
         :token_authenticatable

  attr_accessible :email, :password, :password_confirmation, :remember_me,
                  :full_name, :level
  after_create    :reset_authentication_token!                
  has_many        :campaigns
end
