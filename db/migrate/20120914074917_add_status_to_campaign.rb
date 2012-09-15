class AddStatusToCampaign < ActiveRecord::Migration
  def change
    add_column :campaigns, :status, :text
  end
end
