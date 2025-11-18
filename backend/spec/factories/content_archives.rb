# frozen_string_literal: true

# == Schema Information
#
# Table name: content_archives
#
#  id            :uuid             not null, primary key
#  content_html  :text
#  content_text  :text
#  description   :text
#  error_message :text
#  fetched_at    :datetime
#  image_url     :string(2048)
#  metadata      :jsonb
#  title         :string(500)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  link_id       :uuid             not null
#
# Indexes
#
#  index_content_archives_on_content_text  (content_text) USING gin
#  index_content_archives_on_link_id       (link_id) UNIQUE
#  index_content_archives_on_metadata      (metadata) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (link_id => links.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :content_archive do
    # Default: just reference a link. The Link callback will create the ContentArchive.
    # Most specs should use create(:link).content_archive instead of this factory.
    link

    # Trait for edge cases that need to create a ContentArchive without the Link callback
    # (e.g., testing state machine or transitions in isolation)
    trait :without_link_callback do
      link do
        Link.skip_callback(:create, :after, :create_content_archive_and_enqueue_job)
        FactoryBot.create(:link)
      ensure
        Link.set_callback(:create, :after, :create_content_archive_and_enqueue_job)
      end
    end
  end
end
