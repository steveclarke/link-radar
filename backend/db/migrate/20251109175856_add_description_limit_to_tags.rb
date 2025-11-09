class AddDescriptionLimitToTags < ActiveRecord::Migration[8.1]
  def change
    # Change description from text (unlimited) to string with 500 character limit
    # to match the model validation
    change_column :tags, :description, :string, limit: 500
  end
end
