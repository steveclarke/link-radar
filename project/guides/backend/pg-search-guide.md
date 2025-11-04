# PG Search Guide

Full-text search for models using PostgreSQL via `pg_search` gem.

## Quick Start

**Simple model** (search own fields only):
```ruby
# SearchContent class
class SearchContent::Tag < SearchContent::Base
  SEARCH_FIELDS = { name: "A", description: "B" }
  def self.search_fields = SEARCH_FIELDS
  def self.using = { tsearch: { prefix: true, any_word: true, dictionary: "english" } }
  def self.scope_options = { ignoring: :accents }
end

# Add to model
class Tag < ApplicationRecord
  include Searchable
  searchable_with SearchContent::Tag
end
```

**Complex model** (search associated data):
```ruby
# 1. Add migration: rails g migration AddSearchProjectionToLinks search_projection:text

# 2. SearchContent with projection
class SearchContent::Link < SearchContent::Base
  SEARCH_FIELDS = { title: "A", content_text: "B", note: "C", search_projection: nil }
  
  def self.search_fields = SEARCH_FIELDS
  def self.using
    {
      trigram: {word_similarity: true, threshold: 0.25},
      tsearch: {prefix: true, any_word: true, dictionary: "english"}
    }
  end
  
  def self.scope_options
    { ignoring: :accents, ranked_by: ":tsearch * 0.6 + :trigram * 0.4" }
  end
  
  projection do
    assoc :tags { |tag| [tag.name, tag.slug] }
  end
end

# 3. Enable projection in model
class Link < ApplicationRecord
  include Searchable
  searchable_with SearchContent::Link, project: true
end
```

## Search Methods

**TSearch**: Word-based search with stemming. Best for titles, descriptions, notes.
```ruby
{ tsearch: { prefix: true, any_word: true, dictionary: "english" } }
```

**Trigram**: Fuzzy/similarity search. Best for partial matches, typos, codes.
```ruby
{ trigram: { word_similarity: true, threshold: 0.25 } }
```

**Hybrid**: Use both for complex models (recommended).

## When to Use Search Projections

- **Without projection**: Model only searches its own fields (Tag, Category)
- **With projection**: Need to search associated data or computed values (Link searches tags)

## Field Weights

PostgreSQL ranks A > B > C > D:
- **A**: Names, titles (highest priority)
- **B**: Codes, identifiers
- **C**: Descriptions, notes
- **D**: Metadata
- **nil**: Included but not weighted

## Projection DSL

```ruby
projection do
  assoc :tags { |tag| [tag.name, tag.slug] }      # Association data
  compute :display_name                            # Computed methods
  project_emails                                   # Built-in helpers
  project_phones
  custom { record.title&.upcase&.gsub(/[^A-Z0-9]/, "") }  # Custom tokens
end
```

## Controller Integration

Use `has_scope` to map URL params to search:

```ruby
class Api::V1::LinksController < ApplicationController
  has_scope :search, only: [:index]
  
  def index
    links = apply_scopes(Link.all)
    @pagination, @links = pagy(links)
  end
end

# GET /api/v1/links?search=ruby programming
```

**Special case** (Tags controller uses `.autocomplete` for extension dropdown - limits 20 results, sorts by usage).

## Generator

```bash
rails generate link_radar:searchable category name description           # Simple
rails generate link_radar:searchable product name sku --project          # With projection
rails generate link_radar:searchable product --skip-model-injection      # Skip model
```

Creates SearchContent class, specs, migration (if --project), and rake tasks.

## Projection Maintenance

Search projections rebuild hourly via GoodJob (eventual consistency).

```bash
rake search:rebuild_all          # All models
rake search:rebuild_link         # Specific model
```

```ruby
link.rebuild_search_projection   # Single record
RebuildSearchProjectionsJob.perform_now  # Manual trigger
```

## Testing

```ruby
RSpec.describe Link, type: :model do
  it_behaves_like "searchable model", {
    search_content_class: SearchContent::Link,
    setup: ->(record) {
      record.update!(title: "Ruby Programming")
      record.tags << create(:tag, name: "Rails")
      ["Ruby", "Programming", "Rails"]
    }
  }
end
```

Tests basic search, projection search, rebuilds, prefix search, edge cases, case insensitivity.

## PostgreSQL Extensions

```ruby
enable_extension "unaccent"  # Accent-insensitive search
enable_extension "pg_trgm"   # Trigram similarity
```

## Performance

No specialized indexes yet. Add GIN indexes when search > 1 second or high CPU usage observed.
