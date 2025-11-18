class AddSearchProjectionToLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :links, :search_projection, :text
  end
end
