# Sorting with saltbox-sort_by_columns

This document explains how to use the `saltbox-sort_by_columns` gem for sorting API results.

## Overview

The gem provides URL parameter-based sorting for your API endpoints using the `?sort=` query parameter.

## Basic Usage

### URL Parameter Format

```
?sort=column:direction
```

- **column**: The name of the column to sort by
- **direction**: Either `asc` (ascending) or `desc` (descending)

### Multiple Column Sorting

You can sort by multiple columns by separating them with commas:

```
?sort=column1:direction1,column2:direction2
```

## Links API

### Available Sort Columns

| Column | Type | Description |
|--------|------|-------------|
| `title` | Simple | Sort by link title |
| `created_at` | Simple | Sort by creation date |
| `updated_at` | Simple | Sort by last update date |
| `fetched_at` | Simple | Sort by when content was fetched |
| `c_tag_count` | Custom | Sort by number of tags (custom scope) |

### Examples

#### Sort by title (ascending)
```bash
GET /api/v1/links?sort=title:asc
```

#### Sort by creation date (descending, most recent first)
```bash
GET /api/v1/links?sort=created_at:desc
```

#### Sort by multiple columns
```bash
# Sort by title ascending, then by created_at descending
GET /api/v1/links?sort=title:asc,created_at:desc
```

#### Sort by tag count (most tagged first)
```bash
# Custom scope - shows links with most tags first
GET /api/v1/links?sort=c_tag_count:desc
```

#### Combine with pagination
```bash
GET /api/v1/links?sort=created_at:desc&page=2&items=20
```

## Tags API

### Available Sort Columns

| Column | Type | Description |
|--------|------|-------------|
| `name` | Simple | Sort alphabetically by tag name |
| `usage_count` | Simple | Sort by how often tag is used |
| `last_used_at` | Simple | Sort by when tag was last used |
| `created_at` | Simple | Sort by creation date |

### Examples

#### Sort tags alphabetically
```bash
GET /api/v1/tags?sort=name:asc
```

#### Sort by most used
```bash
GET /api/v1/tags?sort=usage_count:desc
```

#### Sort by recently used
```bash
GET /api/v1/tags?sort=last_used_at:desc
```

## Custom Scopes

Custom scope columns are prefixed with `c_` and backed by custom ActiveRecord scopes.

### Link.c_tag_count

This custom scope sorts links by the number of tags they have:

```ruby
# In Link model
scope :sorted_by_tag_count, ->(direction) {
  left_joins(:link_tags)
    .group("links.id")
    .order(Arel.sql("COUNT(link_tags.id) #{direction}, links.title #{direction}"))
}
```

**Important**: Custom scope columns must be used alone and cannot be combined with other sort columns.

## Error Handling

### Development Environment
- Invalid column names will raise an `ArgumentError`
- Helps catch issues during development
- Provides detailed error messages

### Production Environment
- Invalid columns are silently ignored
- Warnings are logged
- Valid columns are still processed

## Implementation Details

### Models

Models include the `Saltbox::SortByColumns::Model` module and declare sortable columns:

```ruby
class Link < ApplicationRecord
  include Saltbox::SortByColumns::Model
  
  sort_by_columns :title, :created_at, :c_tag_count
  
  # Custom scopes use the naming convention: c_* becomes sorted_by_*
  scope :sorted_by_tag_count, ->(direction) {
    # ... custom sorting logic
  }
end
```

### Controllers

Controllers include the `Saltbox::SortByColumns::Controller` module and use `apply_scopes`:

```ruby
class LinksController < ApplicationController
  include Saltbox::SortByColumns::Controller
  
  def index
    links = apply_scopes(Link.all)
    @pagination, @links = pagy(links)
  end
end
```

## Benefits

- **Clean API**: Simple, predictable URL parameters
- **Type Safety**: Only declared columns are sortable
- **Flexibility**: Supports simple columns, associations, and custom scopes
- **Integration**: Works seamlessly with pagination (pagy)
- **Security**: Prevents SQL injection and parameter pollution
- **Performance**: Uses database indexes for efficient sorting

## References

- [saltbox-sort_by_columns GitHub](https://github.com/myunio/saltbox-sort_by_columns)
- [has_scope gem](https://github.com/heartcombo/has_scope)

