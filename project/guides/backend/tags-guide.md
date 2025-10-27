# Tags Guide

## Quick Overview

Tags are labels for organizing and discovering links. They support:
- **Autocomplete** - Search with popular tags first
- **Auto-creation** - New tags created automatically when assigned to links
- **Usage tracking** - Counts and last-used timestamps
- **URL-friendly slugs** - Auto-generated from tag names

## API Endpoints

All endpoints use `/api/v1/tags` with JSON format.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/tags` | List all tags (by usage) |
| `GET` | `/tags?search=query` | Autocomplete search (top 20) |
| `GET` | `/tags/:id` | Show tag with recent links |
| `POST` | `/tags` | Create tag |
| `PATCH` | `/tags/:id` | Update tag |
| `DELETE` | `/tags/:id` | Delete tag |

## Response Format

**Tag object:**
```json
{
  "id": "uuid",
  "name": "JavaScript",
  "slug": "javascript",
  "description": "Optional description",
  "usage_count": 42,
  "last_used_at": "2025-10-27T19:00:00Z",
  "created_at": "2025-10-25T19:08:31Z",
  "updated_at": "2025-10-27T19:00:00Z"
}
```

## Autocomplete Pattern

**Frontend implementation:**
```javascript
// As user types
async function searchTags(query) {
  const response = await fetch(`/api/v1/tags?search=${query}`);
  const { data } = await response.json();
  // data.tags contains up to 20 results, sorted by usage_count desc
}
```

**Behavior:**
- Empty query → All tags alphabetically
- With query → Case-insensitive partial match, sorted by popularity
- Limit: 20 results

## Assigning Tags to Links

Tags are assigned via the `tag_names` array when creating/updating links.

**Create link with tags:**
```json
POST /api/v1/links
{
  "link": {
    "submitted_url": "https://example.com",
    "tag_names": ["JavaScript", "Tutorial", "Frontend"]
  }
}
```

**Update link tags:**
```json
PATCH /api/v1/links/:id
{
  "link": {
    "tag_names": ["JavaScript", "React"]  // Replaces existing tags
  }
}
```

**Clear all tags:**
```json
{
  "link": {
    "tag_names": []  // Empty array removes all tags
  }
}
```

**Auto-creation:** Tags that don't exist are created automatically. Names are normalized (stripped, de-duplicated).

## Links Response

Links include their tags:
```json
{
  "data": {
    "link": {
      "id": "uuid",
      "url": "https://example.com",
      "title": "Example",
      "tags": [
        {"id": "uuid", "name": "JavaScript", "slug": "javascript"},
        {"id": "uuid", "name": "Tutorial", "slug": "tutorial"}
      ]
    }
  }
}
```

## Key Constraints

- **Name:** 1-100 characters, required
- **Slug:** Auto-generated, unique, 1-100 characters
- **Description:** Optional, max 500 characters
- **Usage count:** Auto-incremented/decremented when tags added/removed from links

## Model Reference

See implementation details:
- `app/models/tag.rb` - Tag model with scopes and autocomplete logic
- `app/models/link.rb` - Tag assignment via `tag_names` attribute
- `app/models/link_tag.rb` - Join model with usage tracking callbacks
- `app/controllers/api/v1/tags_controller.rb` - Tag API endpoints

## Bruno Collection

Test endpoints: `backend/bruno/Tags/`

