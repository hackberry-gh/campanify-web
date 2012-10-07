module Jobs
  class CreateApp < Struct.new(:slug)
    include Campanify            
    def perform
      puts create_app(slug)
    end
    def failure
      # page_sysadmin_in_the_middle_of_the_night
    end    
  end
  
  class DestroyApp < Struct.new(:slug)
    include Campanify      
    def perform      
      puts destroy_app(slug)
    end
    def failure
      # page_sysadmin_in_the_middle_of_the_night
    end
  end
  
  class ChangePlan < Struct.new(:slug, :target_plan)
    include Campanify      
    def perform      
      puts change_plan(slug, target_plan)
    end
    def failure
      # page_sysadmin_in_the_middle_of_the_night
    end
  end
  
  class ChangeTheme < Struct.new(:slug, :theme)
    include Campanify      
    def perform      
      puts change_theme(slug, theme)
    end
    def failure
      # page_sysadmin_in_the_middle_of_the_night
    end
  end
end