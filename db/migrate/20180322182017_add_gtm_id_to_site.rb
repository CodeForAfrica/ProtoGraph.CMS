class AddGtmIdToSite < ActiveRecord::Migration[5.1]
  def change
    add_column :sites, :gtm_id, :string
  end
end
