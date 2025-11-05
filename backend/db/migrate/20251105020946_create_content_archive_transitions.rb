class CreateContentArchiveTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :content_archive_transitions, id: :uuid do |t|
      # Official Statesman fields
      t.string :to_state, null: false
      t.jsonb :metadata, default: {}
      t.integer :sort_key, null: false
      t.references :content_archive, null: false, foreign_key: true, type: :uuid
      t.boolean :most_recent, null: false

      t.timestamps
    end

    # Official Statesman indexes
    add_index :content_archive_transitions,
              [:content_archive_id, :sort_key],
              unique: true,
              name: "index_content_archive_transitions_parent_sort"

    add_index :content_archive_transitions,
              [:content_archive_id, :most_recent],
              unique: true,
              where: "most_recent",
              name: "index_content_archive_transitions_parent_most_recent"
  end
end

