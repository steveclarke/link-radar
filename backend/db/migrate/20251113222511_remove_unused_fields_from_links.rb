# frozen_string_literal: true

# Remove unused submitted_url and metadata fields from links table
#
# submitted_url was used to store original user input, but we only need
# the normalized url field. Original input adds unnecessary complexity.
#
# metadata was a jsonb field that was never populated or used anywhere.
class RemoveUnusedFieldsFromLinks < ActiveRecord::Migration[8.1]
  def change
    # Remove submitted_url column (original user input, no longer needed)
    remove_column :links, :submitted_url, :string, limit: 2048, null: false

    # Remove metadata column and its GIN index
    remove_index :links, name: "index_links_on_metadata", if_exists: true
    remove_column :links, :metadata, :jsonb
  end
end
