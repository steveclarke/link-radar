# frozen_string_literal: true

class AddCascadeDeleteToContentArchiveTransitions < ActiveRecord::Migration[8.1]
  def up
    # Remove existing foreign key
    remove_foreign_key :content_archive_transitions, :content_archives

    # Add foreign key with cascade delete
    add_foreign_key :content_archive_transitions, :content_archives, on_delete: :cascade
  end

  def down
    # Remove cascade foreign key
    remove_foreign_key :content_archive_transitions, :content_archives

    # Add back original foreign key without cascade
    add_foreign_key :content_archive_transitions, :content_archives
  end
end
