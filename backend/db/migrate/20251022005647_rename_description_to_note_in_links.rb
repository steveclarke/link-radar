class RenameDescriptionToNoteInLinks < ActiveRecord::Migration[8.1]
  def change
    rename_column :links, :description, :note
  end
end
