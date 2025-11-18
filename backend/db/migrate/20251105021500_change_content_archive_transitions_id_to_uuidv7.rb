# frozen_string_literal: true

class ChangeContentArchiveTransitionsIdToUuidv7 < ActiveRecord::Migration[8.1]
  def up
    change_column_default :content_archive_transitions, :id, from: "gen_random_uuid()", to: -> { "uuidv7()" }
  end

  def down
    change_column_default :content_archive_transitions, :id, from: -> { "uuidv7()" }, to: "gen_random_uuid()"
  end
end
