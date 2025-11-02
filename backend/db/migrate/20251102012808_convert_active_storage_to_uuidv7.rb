class ConvertActiveStorageToUuidv7 < ActiveRecord::Migration[8.1]
  def up
    # Change default for active_storage_blobs.id to use uuidv7()
    change_column_default :active_storage_blobs, :id, from: -> { "gen_random_uuid()" }, to: -> { "uuidv7()" }

    # Change default for active_storage_attachments.id to use uuidv7()
    change_column_default :active_storage_attachments, :id, from: -> { "gen_random_uuid()" }, to: -> { "uuidv7()" }

    # Change default for active_storage_variant_records.id to use uuidv7()
    change_column_default :active_storage_variant_records, :id, from: -> { "gen_random_uuid()" }, to: -> { "uuidv7()" }
  end

  def down
    # Revert back to gen_random_uuid() if migration is rolled back
    change_column_default :active_storage_blobs, :id, from: -> { "uuidv7()" }, to: -> { "gen_random_uuid()" }
    change_column_default :active_storage_attachments, :id, from: -> { "uuidv7()" }, to: -> { "gen_random_uuid()" }
    change_column_default :active_storage_variant_records, :id, from: -> { "uuidv7()" }, to: -> { "gen_random_uuid()" }
  end
end
