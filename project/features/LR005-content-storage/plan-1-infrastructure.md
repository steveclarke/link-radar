# LR005 - Content Archival & Storage: Infrastructure Plan

## Overview

This plan establishes the foundational infrastructure for content archival:
- External gem dependencies for content extraction
- Configuration system for timeouts, limits, and User-Agent
- Database schema with ContentArchive model and state machine
- Model associations connecting Link → ContentArchive

**Key components created:**
- ContentArchiveConfig (Anyway Config pattern)
- content_archives table with UUIDv7 primary keys
- Statesman state machine with 6 states and transition tracking
- Link model integration with cascade delete

**References:** 
- Technical Spec: [spec.md](spec.md) sections 2, 3, 5.4, 6
- Requirements: [requirements.md](requirements.md) sections 2, 3

## Table of Contents

1. [Phase 1: Prerequisites & Setup](#1-phase-1-prerequisites--setup)
2. [Phase 2: Database Schema & Models](#2-phase-2-database-schema--models)

---

## 1. Phase 1: Prerequisites & Setup

**Implements:** spec.md#5.5 (External Gem Dependencies), spec.md#6 (Configuration Architecture)

Add required external gems and create configuration infrastructure for content archival.

### 1.1 Add Gems to Gemfile

**Add these gems to `backend/Gemfile`** (after existing production gems, before development/test groups):

- [ ] Add metainspector gem
- [ ] Add ruby-readability gem
- [ ] Add loofah gem
- [ ] Add faraday gem
- [ ] Add addressable gem

```ruby
# Content archival and extraction
gem "metainspector"      # OpenGraph/Twitter Card metadata extraction
gem "ruby-readability"   # Main content extraction (Mozilla Readability algorithm)
gem "loofah"            # HTML sanitization (XSS protection)
gem "faraday"           # HTTP client with timeout/redirect support
gem "addressable"       # URL parsing and normalization
```

- [ ] Run `bundle install` to install new gems
- [ ] Verify gems installed: `bundle list | grep -E "(metainspector|ruby-readability|loofah|faraday|addressable)"`

### 1.2 Create ContentArchiveConfig

**Create `backend/config/configs/content_archive_config.rb`** following ApplicationConfig pattern:

- [ ] Create configuration class

```ruby
# frozen_string_literal: true

# Configuration for content archival system
#
# Manages timeouts, limits, retry settings, and User-Agent for web content fetching.
# Values can be set via environment variables, YAML file, or Rails credentials.
#
# @example Accessing configuration
#   ContentArchiveConfig.connect_timeout  # => 10
#   ContentArchiveConfig.user_agent       # => "LinkRadar/1.0 (+https://github.com/...)"
#
# @example Environment variables
#   CONTENT_ARCHIVE_CONNECT_TIMEOUT=15
#   CONTENT_ARCHIVE_USER_AGENT_CONTACT_URL=https://linkradar.example.com
#
class ContentArchiveConfig < ApplicationConfig
  attr_config(
    # HTTP timeouts
    connect_timeout: 10,        # seconds to wait for connection
    read_timeout: 15,           # seconds to wait for response
    
    # Fetch limits
    max_redirects: 5,           # maximum redirect hops to follow
    max_file_size: 10_485_760,  # 10MB in bytes
    
    # Retry configuration
    max_retries: 3,             # total retry attempts (including initial)
    retry_backoff_base: 2,      # backoff base in seconds (2s, 4s, 8s...)
    
    # User-Agent identification
    :user_agent_contact_url,    # REQUIRED: contact URL for User-Agent header
    
    # Feature flag
    enabled: true               # global enable/disable for archival
  )

  # Builds complete User-Agent string for HTTP requests
  #
  # Format: "LinkRadar/1.0 (+{contact_url})"
  #
  # @return [String] formatted User-Agent header value
  # @example
  #   ContentArchiveConfig.user_agent
  #   # => "LinkRadar/1.0 (+https://github.com/username/link-radar)"
  def user_agent
    "LinkRadar/1.0 (+#{user_agent_contact_url})"
  end

  # Validates that required configuration is present
  #
  # @raise [Anyway::Config::ValidationError] if user_agent_contact_url is missing
  # @return [void]
  def validate!
    super
    if user_agent_contact_url.blank?
      raise Anyway::Config::ValidationError,
        "user_agent_contact_url is required for ContentArchiveConfig"
    end
  end
end
```

### 1.3 Create Configuration YAML

**Create `backend/config/content_archive.yml`** with development defaults:

- [ ] Create YAML configuration file

```yaml
# Content Archival Configuration
#
# These are default values. Override via environment variables:
#   CONTENT_ARCHIVE_CONNECT_TIMEOUT=15
#   CONTENT_ARCHIVE_USER_AGENT_CONTACT_URL=https://your-site.com
#
# Or via Rails credentials:
#   rails credentials:edit
#   content_archive:
#     user_agent_contact_url: https://your-site.com

default: &default
  # HTTP timeouts (seconds)
  connect_timeout: 10
  read_timeout: 15
  
  # Fetch limits
  max_redirects: 5
  max_file_size: 10485760  # 10MB
  
  # Retry configuration
  max_retries: 3
  retry_backoff_base: 2
  
  # User-Agent contact URL (REQUIRED - set via environment or credentials)
  # Example: https://github.com/yourusername/link-radar
  user_agent_contact_url: <%= ENV['CONTENT_ARCHIVE_USER_AGENT_CONTACT_URL'] %>
  
  # Feature flag
  enabled: true

development:
  <<: *default

test:
  <<: *default
  enabled: false  # Disable archival in tests by default

production:
  <<: *default
```

### 1.4 Verify Statesman Configuration

**Check `backend/config/initializers/statesman.rb`** exists:

- [ ] Verify Statesman initializer exists (should already be present from spec.md#5.4)
- [ ] If missing, create with basic Statesman configuration:

```ruby
# frozen_string_literal: true

Statesman.configure do
  # Optional: Configure JSON serialization for metadata
  # storage_adapter(Statesman::Adapters::ActiveRecord)
end
```

---

## 2. Phase 2: Database Schema & Models

**Implements:** spec.md#3 (Data Architecture), spec.md#5.4 (State Machine Setup)

Create database tables, state machine, and model integration for content archival.

### 2.1 Create ContentArchive Migration

**Create migration: `rails g migration CreateContentArchives`**

- [ ] Generate migration file
- [ ] Implement migration following UUIDv7 pattern from CreateLinks

```ruby
# frozen_string_literal: true

class CreateContentArchives < ActiveRecord::Migration[8.1]
  def change
    create_table :content_archives, id: false do |t|
      t.uuid :id, primary_key: true, default: -> { "uuidv7()" }, null: false

      # Foreign key to links (one-to-one)
      t.uuid :link_id, null: false

      # Error tracking
      t.text :error_message

      # Extracted content
      t.text :content_html
      t.text :content_text

      # Extracted metadata
      t.string :title, limit: 500
      t.text :description
      t.string :image_url, limit: 2048
      t.jsonb :metadata, default: {}

      # Fetch tracking
      t.datetime :fetched_at

      t.timestamps
    end

    # Indexes
    add_index :content_archives, :link_id, unique: true
    add_index :content_archives, :metadata, using: :gin
    add_index :content_archives, :content_text, using: :gin, opclass: :gin_trgm_ops

    # Foreign key with cascade delete
    add_foreign_key :content_archives, :links, on_delete: :cascade
  end
end
```

**Note on indexes:**
- `link_id` (unique): Enforces one-to-one relationship, used for lookups
- `metadata` (GIN): Enables efficient JSONB queries (future use)
- `content_text` (GIN trigram): Enables full-text search (future use, requires pg_trgm extension)

### 2.2 Drop Unused Link Columns Migration

**Add to same migration file** (combine operations):

- [ ] Add column removal logic to migration

```ruby
class CreateContentArchives < ActiveRecord::Migration[8.1]
  def change
    # ... create_table :content_archives (above) ...

    # Drop unused content-related columns from links table
    # These columns were never populated and are being replaced by ContentArchive
    change_table :links do |t|
      t.remove :content_text
      t.remove :raw_html
      t.remove :fetch_error
      t.remove :fetched_at
      t.remove :image_url
      t.remove :title
      # Keep metadata column on links for future non-archive metadata
      # Keep fetch_state enum for backward compatibility during transition
    end

    # Drop the fetch_state enum (no longer needed)
    execute "DROP TYPE link_fetch_state"
    remove_column :links, :fetch_state
  end
end
```

- [ ] Run migration: `rails db:migrate`
- [ ] Verify schema updated: `rails db:migrate:status`

### 2.3 Generate State Machine

**Run state machine generator** from spec.md#5.4:

- [ ] Generate state machine: `rails generate link_radar:state_machine ContentArchive pending:initial processing success failed invalid_url blocked`
- [ ] Verify created files:
  - `app/state_machines/content_archive_state_machine.rb`
  - `app/models/content_archive_transition.rb`
  - `db/migrate/YYYYMMDDHHMMSS_create_content_archive_transitions.rb`
  - `spec/factories/content_archive_transitions.rb`
  - `spec/models/content_archive_transition_spec.rb`
  - `spec/models/content_archive_state_machine_spec.rb`

### 2.4 Customize State Machine Transitions

**Edit `app/state_machines/content_archive_state_machine.rb`** to define allowed transitions per spec.md#3.2:

- [ ] Replace default transitions with custom transition rules

```ruby
# frozen_string_literal: true

# State machine for tracking content archival lifecycle
#
# States:
#   - pending: Archive created, waiting for background job
#   - processing: Job actively fetching and extracting content
#   - success: Content successfully archived
#   - failed: Failed after all retries exhausted
#   - invalid_url: URL validation failed (invalid scheme, malformed)
#   - blocked: URL blocked for security (private IP, SSRF)
#
# Transition metadata stored in content_archive_transitions.metadata:
#   - error_message (string): Error details for failures
#   - validation_reason (string): Why URL was blocked/invalid
#   - fetch_duration_ms (integer): Time taken for successful fetches
#   - retry_count (integer): Current retry attempt number
#   - http_status (integer): HTTP response code if applicable
#
class ContentArchiveStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :processing
  state :success
  state :failed
  state :invalid_url
  state :blocked

  # Define allowed transitions per spec.md#3.2
  transition from: :pending, to: [:processing, :blocked, :invalid_url]
  transition from: :processing, to: [:success, :failed, :blocked]
end
```

### 2.5 Create ContentArchive Model

**Create `app/models/content_archive.rb`** with state machine integration:

- [ ] Create model file

```ruby
# frozen_string_literal: true

# Represents archived web page content for a Link
#
# ContentArchive stores extracted content, metadata, and tracks archival status
# through a Statesman state machine. Each Link has one ContentArchive (one-to-one).
#
# == Schema Information
#
# Table name: content_archives
#
#  id             :uuid             not null, primary key
#  link_id        :uuid             not null
#  error_message  :text
#  content_html   :text
#  content_text   :text
#  title          :string(500)
#  description    :text
#  image_url      :string(2048)
#  metadata       :jsonb
#  fetched_at     :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_content_archives_on_link_id       (link_id) UNIQUE
#  index_content_archives_on_metadata      (metadata) USING gin
#  index_content_archives_on_content_text  (content_text) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (link_id => links.id) ON DELETE CASCADE
#
class ContentArchive < ApplicationRecord
  # =============================================================================
  # Associations
  # =============================================================================
  
  belongs_to :link

  # =============================================================================
  # Statesman State Machine Integration
  # =============================================================================
  # This section was generated by: rails generate link_radar:state_machine ContentArchive
  #
  # State machine: ContentArchiveStateMachine
  # Transition model: ContentArchiveTransition
  #
  # Documentation:
  #   - Statesman gem: https://github.com/gocardless/statesman
  #   - LinkRadar guide: project/guides/backend/state-machines-guide.md
  #
  # Usage:
  #   archive.current_state
  #   archive.transition_to!(:processing)
  #   ContentArchive.in_state(:pending)
  # =============================================================================

  # Association to transition records
  has_many :content_archive_transitions, autosave: false, dependent: :destroy

  # Statesman query scopes and integration
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: ContentArchiveTransition,
    initial_state: :pending
  ]

  # State machine instance
  def state_machine
    @state_machine ||= ContentArchiveStateMachine.new(
      self,
      transition_class: ContentArchiveTransition,
      association_name: :content_archive_transitions
    )
  end

  # Convenience delegate methods for easier access
  delegate :current_state, :can_transition_to?, :transition_to!,
    :allowed_transitions, to: :state_machine

  # =============================================================================
  # End Statesman State Machine Integration
  # =============================================================================

  # =============================================================================
  # Validations
  # =============================================================================

  validates :link_id, presence: true
  validates :title, length: {maximum: 500}, allow_nil: true
  validates :image_url, length: {maximum: 2048}, allow_nil: true
end
```

- [ ] Run migration for transitions table: `rails db:migrate`
- [ ] Verify ContentArchiveTransition model exists
- [ ] Update schema annotations: `bundle exec annotaterb models`

### 2.6 Update Link Model Integration

**Edit `app/models/link.rb`** to add ContentArchive association:

- [ ] Add has_one association to Link model

```ruby
class Link < ApplicationRecord
  # Associations
  has_many :link_tags, dependent: :destroy
  has_many :tags, through: :link_tags
  has_one :content_archive, dependent: :destroy  # ADD THIS LINE

  # ... rest of Link model ...
end
```

- [ ] Update schema annotations: `bundle exec annotaterb models`

### 2.7 Verification & Sample Data

**Verify infrastructure in Rails console:**

- [ ] Start console: `rails console`
- [ ] Test configuration: `ContentArchiveConfig.connect_timeout`
- [ ] Test User-Agent (will fail if URL not set - expected): `ContentArchiveConfig.user_agent`
- [ ] Create test link: `link = Link.create!(url: "https://example.com", submitted_url: "https://example.com")`
- [ ] Create test archive: `archive = ContentArchive.create!(link: link)`
- [ ] Check initial state: `archive.current_state` (should be "pending")
- [ ] Test transition: `archive.transition_to!(:processing)`
- [ ] Check new state: `archive.current_state` (should be "processing")
- [ ] Verify cascade delete: `link.destroy` (should delete archive and transitions)
- [ ] Clean up: `Link.destroy_all; ContentArchive.destroy_all`

---

## Completion Checklist

Infrastructure complete when:
- [ ] All gems installed and verified
- [ ] ContentArchiveConfig loads without errors
- [ ] ContentArchive table exists with proper indexes
- [ ] Unused Link columns dropped
- [ ] State machine transitions work correctly
- [ ] Link → ContentArchive association works
- [ ] Cascade delete works (deleting link deletes archive and transitions)
- [ ] Schema annotations updated

**Next:** Proceed to [plan-2-services.md](plan-2-services.md) to implement content pipeline services.

