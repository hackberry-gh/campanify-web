class CreateCampaigns < ActiveRecord::Migration
  def change
    create_table :campaigns do |t|
      t.string :name
      t.string :slug
      t.string :plan
      t.integer :user_id

      t.timestamps
    end
    add_index :campaigns, :name
    add_index :campaigns, :slug
    add_index :campaigns, :user_id        
  end
end
