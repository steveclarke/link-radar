ActiveRecordDoctor.configure do |config|
  global :ignore_tables, %w[
    good_jobs
    good_job_executions
    versions
    models
    tool_calls
  ]

  detector :missing_presence_validation,
    # Note: Most of our model boolean attributes below are false-flags because
    # they are validated using the custom `is_boolean` validator.
    # Monetized fields (_cents and _currency) are handled by money-rails gem validation.
    ignore_attributes: %w[
      GoodJob::DiscreteExecution.active_job_id
      GoodJob::Execution.active_job_id
      GoodJob::Job.id
      ActiveStorage::Attachment.name
      ActiveStorage::Attachment.record_type
      ActiveStorage::Blob.key
      ActiveStorage::Blob.filename
      ActiveStorage::Blob.byte_size
      ActiveStorage::VariantRecord.variation_digest
      Message.role
      ToolCall.tool_call_id
      ToolCall.name
    ]

  detector :incorrect_length_validation,
    ignore_attributes: %w[]

  detector :undefined_table_references,
    ignore_models: %w[
      ActionText::RichText
      ActionText::EncryptedRichText
      ActiveStorage::VariantRecord
      ActiveStorage::Blob
      ActiveStorage::Attachment
      ActionMailbox::InboundEmail
    ]

  detector :incorrect_dependent_option,
    ignore_associations: %w[]

  detector :extraneous_indexes,
    enabled: false

  detector :missing_unique_indexes,
    enabled: false

  detector :table_without_timestamps,
    ignore_tables: %w[
      active_storage_attachments
      active_storage_blobs
      schema_migrations
      active_storage_variant_records
    ]

  detector :missing_foreign_keys,
    ignore_models: %w[
      GoodJob::Execution
      GoodJob::Job
    ]
end
