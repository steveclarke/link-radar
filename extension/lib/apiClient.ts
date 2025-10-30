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
  Link,
  LinkApiResponse,
  LinkParams,
  Tag,
  TagsApiResponse,
  UpdateLinkParams,
} from "./types"
import { getActiveConfig } from "./settings"

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
  const config = await getActiveConfig()

  const response = await fetch(`${config.url}${path}`, {
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
      submitted_url: params.url,
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
