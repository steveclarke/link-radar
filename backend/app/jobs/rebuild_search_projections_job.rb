# Rebuilds search projections for all searchable models with projections
#
# This job ensures search projections stay current with associated data changes
# by rebuilding them for all models that use `project: true`. This maintains
# search accuracy through eventual consistency without requiring complex
# change tracking or callbacks.
#
# @example Enqueue the job
#   RebuildSearchProjectionsJob.perform_later
#
# @example Run immediately (testing)
#   RebuildSearchProjectionsJob.perform_now
#
# @see SearchContent::Base
# @see Searchable concern
class RebuildSearchProjectionsJob < ApplicationJob
  queue_as :default

  # Rebuilds search projections for all models with search projections
  #
  # Processes each searchable model that uses projections in batches to avoid
  # memory issues and long-running transactions.
  #
  # Models with projections: Link
  #
  # @param args [Array] Arguments (not used, but required for job interface)
  # @return [void]
  #
  # @example Typical usage
  #   # Rebuilds projections for all links in batches of 100
  #   RebuildSearchProjectionsJob.perform_now
  def perform(*args)
    models_with_projections = [
      Link
    ]

    models_with_projections.each do |model_class|
      Rails.logger.info "Rebuilding search projections for #{model_class.name}..."

      count = 0
      model_class.find_each(batch_size: 100) do |record|
        record.rebuild_search_projection
        count += 1
      end

      Rails.logger.info "✓ Rebuilt #{count} #{model_class.name} search projections"
    end

    Rails.logger.info "All search projections rebuilt successfully!"
  end
end
