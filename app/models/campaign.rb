class Campaign < ActiveRecord::Base
  include Campanify::Heroku
  
  ONLINE        = "online"
  MAINTENANCE   = "maintenance"
  PENDING       = "pending"  
  DELETED       = "deleted"    
  
  attr_accessible :name, :plan, :slug, :user_id, :status, :theme
  belongs_to :user
  validates_presence_of :name, :plan, :slug, :user_id
  validates_uniqueness_of :name, :slug
  
  before_validation :set_slug
  after_create      :create_app
  before_update     :change_plan
  before_update     :change_theme  
  before_destroy    :destroy_app
  
  attr_accessor  :migration_steps
  
  def serializable_hash(options = {})
    super((options || { }).merge({
        :methods => [:price]
    }))
  end
  
  def set_status(status)
    self.update_column(:status, status)
    Pusher['campaigns'].trigger('update', self)
  end
  
  def price
    if self.status == ONLINE
      unless @price = Rails.cache.read("#{self.slug}-price")
        addon_price = heroku.get_addons(slug).body.sum{|addon| addon["price"]["cents"]}
        ps_price = (heroku.get_ps(Campaign.first.slug).body.count - 1) * 3500
        campanify_price = Campanify::Plans.configuration(plan.to_sym)[:campanify_fee]
        addon_price + ps_price + campanify_price
        @price = addon_price < 0 ? 0 : addon_price
        Rails.cache.write("#{self.slug}-price", @price)
      end
    else
      0
    end
  end
  
  private
    
  def set_slug
    self.slug = name.parameterize
  end
  
  def create_app
    set_status PENDING
    Delayed::Job.enqueue(Jobs::CreateApp.new(self.slug))
  end
  
  def destroy_app
    set_status DELETED
    Delayed::Job.enqueue(Jobs::DestroyApp.new(self.slug))
  end
  
  def change_plan    
    if self.plan_was != self.plan && self.status == ONLINE
      set_status PENDING
      target_plan = self.plan
      self.plan = self.plan_was
      Delayed::Job.enqueue(Jobs::ChangePlan.new(self.slug, target_plan))
      Rails.cache.delete("#{self.slug}-price")      
    end
  end
  
  def change_theme
    if self.theme_was != self.theme && self.status == ONLINE
      set_status PENDING    
      target_theme = self.theme
      self.theme = self.theme_was      
      Delayed::Job.enqueue(Jobs::ChangeTheme.new(self.slug, target_theme))
    end
  end
  
end
