# frozen_string_literal: true

# Auto-annotate models after migrations
if Rails.env.development?
  require "annotate_rb"

  # Ensure annotaterb runs after migrations
  task :set_annotation_options do
    # You can override config file settings here if needed
    # For example:
    # Annotate.set_defaults(
    #   'position_in_class' => 'before',
    #   'show_indexes' => 'true'
    # )
  end

  Annotate.load_tasks

  # Hook into db:migrate
  Rake::Task["db:migrate"].enhance do
    Rake::Task["annotate_models"].invoke
  end

  # Hook into db:rollback
  Rake::Task["db:rollback"].enhance do
    Rake::Task["annotate_models"].invoke
  end

  # Hook into db:schema:load
  Rake::Task["db:schema:load"].enhance do
    Rake::Task["annotate_models"].invoke
  end
end
