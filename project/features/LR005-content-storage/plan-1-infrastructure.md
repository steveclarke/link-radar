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
# OpenGraph/Twitter Card metadata extraction
gem "metainspector"

# Main content extraction (Mozilla Readability algorithm)
gem "ruby-readability"

# HTML sanitization (XSS protection)
gem "loofah"

# HTTP client with timeout/redirect support
gem "faraday"

# URL parsing and normalization
gem "addressable"
```

- [ ] Run `bundle install` to install new gems
- [ ] Verify gems installed: `bundle list | grep -E "(metainspector|ruby-readability|loofah|faraday|addressable)"`

### 1.2 Create ContentArchiveConfig

**Create `backend/config/configs/content_archive_config.rb`** following ApplicationConfig pattern:

- [ ] Generate configuration class using Anyway Config

```bash
rails generate anyway:config content_archive \
  connect_timeout:integer \
  read_timeout:integer \
  max_redirects:integer \
  max_content_size:integer \
  max_retries:integer \
  retry_backoff_base:integer \
  user_agent_contact_url:string \
  enabled:boolean
```

- [ ] Update generated `config/configs/content_archive_config.rb` with defaults, documentation, and custom methods

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
    :user_agent_contact_url,    # contact URL for User-Agent header
    
    # HTTP timeouts
    connect_timeout: 10,        # seconds to wait for connection
    read_timeout: 15,           # seconds to wait for response
    
    # Fetch limits
    max_redirects: 5,           # maximum redirect hops to follow
    max_content_size: 10_485_760,  # 10MB in bytes
    
    # Retry configuration
    max_retries: 3,             # total retry attempts (including initial)
    retry_backoff_base: 2,      # backoff base in seconds (2s, 4s, 8s...)
    
    # Feature flag
    enabled: true               # global enable/disable for archival
  )
  
  # Require user_agent_contact_url in production
  required :user_agent_contact_url, env: :production

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
end
```

### 1.3 Update Configuration YAML

**Update generated `backend/config/content_archive.yml`** with development defaults:

- [ ] Update generated YAML configuration file with defaults and documentation

```yaml
# Content Archival Configuration
#
# Best practices (see project/guides/backend/configuration-management-guide.md):
# - Defaults → In code (attr_config)
# - Environment-specific → YAML files (this file)
# - Secrets → Rails credentials
# - Production overrides → Environment variables (last resort)

default: &default
  # HTTP timeouts (seconds)
  connect_timeout: 10
  read_timeout: 15
  
  # Fetch limits
  max_redirects: 5
  max_content_size: 10485760  # 10MB
  
  # Retry configuration
  max_retries: 3
  retry_backoff_base: 2
  
  # Feature flag
  enabled: true

development:
  <<: *default

test:
  <<: *default
  enabled: false  # Disable archival in tests by default

production:
  <<: *default
  # Set user_agent_contact_url in credentials
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

      # Foreign key to links (one-to-one with cascade delete)
      t.references :link,
        type: :uuid,
        null: false,
        foreign_key: { on_delete: :cascade },
        index: { unique: true }

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

    # Additional indexes
    add_index :content_archives, :metadata, using: :gin
    add_index :content_archives, :content_text, using: :gin, opclass: :gin_trgm_ops
  end
end
```

**Note on indexes:**
- `link_id` (unique): Created by `t.references`, enforces one-to-one relationship
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
      t.remove :fetch_state
      # Keep metadata column on links for future non-archive metadata
    end

    # Drop the fetch_state enum type
    drop_enum :link_fetch_state
  end
end
```

- [ ] Run migration: `rails db:migrate`
- [ ] Verify schema updated: `rails db:migrate:status`

### 2.3 Create ContentArchive Model

**Create `app/models/content_archive.rb`** with basic structure (Statesman code will be added by generator):

- [ ] Create model file

```ruby
# frozen_string_literal: true

# Represents archived web page content for a Link
#
# ContentArchive stores extracted content, metadata, and tracks archival status
# through a Statesman state machine. Each Link has one ContentArchive (one-to-one).
class ContentArchive < ApplicationRecord
  # =============================================================================
  # Associations
  # =============================================================================
  
  belongs_to :link

  # =============================================================================
  # Statesman State Machine Integration
  # =============================================================================
  # This section will be generated by: rails generate link_radar:state_machine ContentArchive
  # (See next step)

  # =============================================================================
  # Validations
  # =============================================================================

  validates :link_id, presence: true
  validates :title, length: {maximum: 500}, allow_nil: true
  validates :image_url, length: {maximum: 2048}, allow_nil: true
end
```

### 2.4 Generate State Machine

**Run state machine generator** from spec.md#5.4:

- [ ] Generate state machine: `rails generate link_radar:state_machine ContentArchive pending:initial processing success failed invalid_url blocked`
- [ ] Verify created files:
  - `app/state_machines/content_archive_state_machine.rb`
  - `app/models/content_archive_transition.rb`
  - `db/migrate/YYYYMMDDHHMMSS_create_content_archive_transitions.rb`
  - `spec/factories/content_archive_transitions.rb`
  - `spec/models/content_archive_transition_spec.rb`
  - `spec/models/content_archive_state_machine_spec.rb`
- [ ] Verify Statesman code was added to `app/models/content_archive.rb`
- [ ] Run migration for transitions table: `rails db:migrate`

### 2.5 Customize State Machine Transitions

**Edit `app/state_machines/content_archive_state_machine.rb`** to define allowed transitions per spec.md#3.2:

- [ ] Replace default transitions with custom transition rules

```ruby
# frozen_string_literal: true

# State machine for tracking content archival lifecycle
#
# States:
#   - pending: Archive created, waiting for background job
#   - processing: Job actively fetching and extracting content
#   - completed: Content successfully fetched (check content_type for what was fetched)
#   - failed: Could not fetch content (check error_reason for why)
#
# Archive metadata (content_archives.metadata):
#   When completed:
#     - content_type (string): Type of content fetched (html, pdf, image, video, other)
#     - final_url (string): Final URL after redirects
#     - fetched_at (string): ISO8601 timestamp
#
# Transition metadata (content_archive_transitions.metadata):
#   When completed:
#     - fetch_duration_ms (integer): Time taken for fetch
#   When failed:
#     - error_reason (string): Why it failed (blocked, invalid_url, network_error, size_limit, etc.)
#     - error_message (string): Human-readable error details
#     - http_status (integer): HTTP response code if applicable
#     - retry_count (integer): Current retry attempt number
#
class ContentArchiveStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :processing
  state :completed
  state :failed

  # Define allowed transitions per spec.md#3.2
  transition from: :pending, to: [:processing]
  transition from: :processing, to: [:completed, :failed]
end
```

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
- [x] All gems installed and verified
- [x] ContentArchiveConfig loads without errors
- [x] ContentArchive table exists with proper indexes
- [x] Unused Link columns dropped
- [x] State machine transitions work correctly
- [x] Link → ContentArchive association works
- [x] Cascade delete works (deleting link deletes archive and transitions)
- [x] Schema annotations updated

## Additional Work Completed

Beyond the original plan, the following enhancements were made:

- **UUIDv7 Migration**: Changed `content_archive_transitions.id` default from `gen_random_uuid()` to `uuidv7()` for consistency
- **Cascade Delete Fix**: Added `ON DELETE CASCADE` to `content_archive_transitions` foreign key
- **Sample Data Loader**: Updated `lib/dev/sample_data/links.rb` to work with new schema
- **Test Coverage**: All 49 tests passing, including new association tests

## Implementation Summary

**Migrations Created:**
1. `20251105020107_create_content_archives.rb` - Creates content_archives table, drops unused Link columns
2. `20251105020946_create_content_archive_transitions.rb` - Creates transitions table for state machine
3. `20251105021500_change_content_archive_transitions_id_to_uuidv7.rb` - Updates UUID default
4. `20251105021935_add_cascade_delete_to_content_archive_transitions.rb` - Adds cascade delete

**Files Created/Modified:**
- Config: `config/configs/content_archive_config.rb`, `config/content_archive.yml`
- Models: `app/models/content_archive.rb`, `app/models/content_archive_transition.rb`
- State Machine: `app/state_machines/content_archive_state_machine.rb`
- Factories: `spec/factories/content_archives.rb`, `spec/factories/content_archive_transitions.rb`
- Tests: All specs passing (49 examples, 0 failures)
- Updated: `app/models/link.rb`, `app/models/search_content/link.rb`, `lib/dev/sample_data/links.rb`

✅ **Infrastructure Phase Complete!**

**Next:** Proceed to [plan-2-services.md](plan-2-services.md) to implement content pipeline services.

