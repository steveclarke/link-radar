/**
 * @fileoverview API client for backend communication.
 *
 * This layer exists to provide a shared HTTP interface that can be used by both:
 * - Vue components/composables (popup UI, options page)
 * - Service workers (background scripts, context menus)
 *
 * By keeping HTTP logic separate from Vue-specific code, we ensure it's reusable
 * across all extension contexts.
 */
import type {
  ExportApiResponse,
  ExportResult,
  ImportApiResponse,
  ImportMode,
  ImportResult,
  Link,
  LinkApiResponse,
  LinkParams,
  Tag,
  TagsApiResponse,
  UpdateLinkParams,
} from "./types"
import { getActiveEnvironmentConfig } from "./settings"

/**
 * Internal authenticated fetch wrapper. Automatically adds auth header and
 * handles common errors. Dynamically uses the configured backend URL based on
 * environment settings.
 *
 * @param path - API endpoint path (e.g., '/links', '/tags')
 * @param options - RequestInit is the built-in TypeScript type for fetch() options.
 *                  It includes: method, headers, body, mode, credentials, cache, signal, etc.
 *                  This ensures type safety and matches the native fetch() API signature.
 */
async function authenticatedFetch(path: string, options: RequestInit = {}): Promise<any> {
  const config = await getActiveEnvironmentConfig()
  const fullUrl = `${config.url}${path}`

  const response = await fetch(fullUrl, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${config.apiKey}`,
      ...options.headers,
    },
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`API request failed: ${response.status} ${response.statusText} - ${errorText}`)
  }

  // For DELETE requests that return 204 No Content
  if (response.status === 204) {
    return
  }

  return response.json()
}

/**
 * Save a new link to the backend
 */
export async function createLink(params: LinkParams): Promise<any> {
  const payload = {
    link: {
      url: params.url,
      title: params.title,
      note: params.note,
      tag_names: params.tag_names || [],
    },
  }

  return authenticatedFetch("/links", {
    method: "POST",
    body: JSON.stringify(payload),
  })
}

/**
 * Fetch a link by URL from the backend.
 *
 * @param url - The URL to search for
 * @returns Link object matching backend structure if found, otherwise null
 */
export async function fetchLinkByUrl(url: string): Promise<Link | null> {
  try {
    const response = await authenticatedFetch(`/links/by_url?url=${encodeURIComponent(url)}`) as LinkApiResponse
    return response.data.link
  }
  catch (error) {
    // 404 means link not found, which is expected
    if (error instanceof Error && error.message.includes("404")) {
      return null
    }
    throw error
  }
}

/**
 * Get details for a specific link by ID.
 *
 * @param linkId - The unique identifier of the link
 * @returns Link object matching backend structure
 */
export async function fetchLinkById(linkId: string): Promise<Link> {
  const response = await authenticatedFetch(`/links/${linkId}`) as LinkApiResponse
  return response.data.link
}

/**
 * Update an existing link's note and/or tags.
 *
 * @param linkId - The unique identifier of the link to update
 * @param params - Object containing note and/or tag_names to update
 * @returns Link object with the updated data
 */
export async function updateLink(linkId: string, params: UpdateLinkParams): Promise<Link> {
  const payload = {
    link: {
      note: params.note,
      tag_names: params.tag_names || [],
    },
  }

  const response = await authenticatedFetch(`/links/${linkId}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  }) as LinkApiResponse

  return response.data.link
}

/**
 * Delete a link from the backend
 */
export async function deleteLink(linkId: string): Promise<void> {
  await authenticatedFetch(`/links/${linkId}`, {
    method: "DELETE",
  })
}

/**
 * Search for tags by query
 * @param query - Optional search query. If empty, returns all tags sorted by usage
 * @returns Array of tags matching the search query
 */
export async function searchTags(query: string = ""): Promise<Tag[]> {
  const params = query ? `?search=${encodeURIComponent(query)}` : ""
  const response = await authenticatedFetch(`/tags${params}`) as TagsApiResponse
  return response.data.tags
}

/**
 * Export all links to JSON file
 *
 * Calls POST /api/v1/snapshot/export to generate export file on backend.
 * Returns metadata and download URL for retrieving the file.
 *
 * Links tagged with ~temp~ are excluded from exports.
 *
 * @returns Export result with download URL and counts
 * @throws Error if API request fails
 */
export async function exportLinks(): Promise<ExportResult> {
  const response = await authenticatedFetch("/snapshot/export", {
    method: "POST",
  }) as ExportApiResponse

  return response.data
}

/**
 * Import links from uploaded file
 *
 * Calls POST /api/v1/snapshot/import with multipart form data.
 * Accepts LinkRadar native JSON format only.
 *
 * Import modes:
 * - skip (default): Ignore duplicate URLs, keep existing data
 * - update: Overwrite existing links with imported data (except created_at)
 *
 * Entire import is wrapped in transaction - any error rolls back all changes.
 *
 * @param file - JSON file to import (LinkRadar format)
 * @param mode - Import mode: "skip" or "update" (defaults to "skip")
 * @returns Import statistics (links imported/skipped, tags created/reused)
 * @throws Error if API request fails or file is invalid
 */
export async function importLinks(
  file: File,
  mode: ImportMode = "skip",
): Promise<ImportResult> {
  const config = await getActiveEnvironmentConfig()
  const fullUrl = `${config.url}/snapshot/import`

  // Build FormData for multipart upload
  // Note: Content-Type header must NOT be set manually - browser sets it with boundary
  const formData = new FormData()
  formData.append("file", file)
  formData.append("mode", mode)

  const response = await fetch(fullUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      // Note: Do NOT set Content-Type - browser handles it for FormData
    },
    body: formData,
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Import failed: ${response.status} ${response.statusText} - ${errorText}`)
  }

  const result = await response.json() as ImportApiResponse
  return result.data
}
