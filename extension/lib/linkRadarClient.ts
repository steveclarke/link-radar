import { getApiKey } from "./apiKey"
import { BACKEND_URL } from "./config"

/**
 * Parameters for creating a new link
 */
export interface LinkParams {
  url: string
  title: string
  note?: string
  tags?: string[]
}

/**
 * Parameters for updating an existing link
 */
export type UpdateLinkParams = Pick<LinkParams, "note" | "tags">

/**
 * Normalized link object with consistent structure for extension use.
 *
 * The API may return links in various response shapes (nested under 'link' or 'data.link'),
 * with different field names, and with tags as objects. This interface represents the
 * standardized format after normalization, ensuring consistent access throughout the extension.
 */
export interface Link {
  id: string
  url: string
  title: string
  note: string
  tags: string[] // Tag names only (normalized from tag objects)
}

/**
 * Tag object returned from API
 */
export interface Tag {
  id: string
  name: string
  slug: string
  usage_count: number
}

/**
 * Internal authenticated fetch wrapper
 * Automatically adds auth header and handles common errors
 */
async function authenticatedFetch(path: string, options: RequestInit = {}): Promise<any> {
  const apiKey = await getApiKey()

  const response = await fetch(`${BACKEND_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
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
 * Normalize API response to consistent Link format.
 *
 * The backend API returns links in varying structures depending on the endpoint:
 * - Single resource: { link: {...} }
 * - Collection: { data: { links: [...] } }
 * - Direct object in some cases
 *
 * This function:
 * - Extracts the link from any response structure
 * - Maps tag objects [{id, name, slug}] to simple name strings
 * - Handles field name variations (url vs submitted_url)
 * - Provides sensible defaults (empty string for missing note)
 *
 * @returns A Link object with guaranteed shape matching the Link interface
 */
function normalizeLinkResponse(rawData: any): Link {
  const link = rawData?.link ?? rawData?.data?.link ?? rawData

  if (!link) {
    throw new Error("Invalid link response from API")
  }

  const tags = Array.isArray(link.tags) ? link.tags.map((tag: any) => tag?.name).filter(Boolean) : []

  return {
    id: link.id,
    url: link.url ?? link.submitted_url,
    title: link.title,
    note: link.note ?? "",
    tags,
  }
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
      tag_names: params.tags || [],
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
 * @returns A normalized Link object (with consistent structure and tag names as strings)
 *          if found, otherwise null if no matching link exists
 */
export async function fetchLinkByUrl(url: string): Promise<Link | null> {
  const json = await authenticatedFetch(`/links?url=${encodeURIComponent(url)}`)
  const links = json?.data?.links ?? []
  if (Array.isArray(links) && links.length > 0) {
    return normalizeLinkResponse(links[0])
  }
  return null
}

/**
 * Get details for a specific link by ID.
 *
 * @param linkId - The unique identifier of the link
 * @returns A normalized Link object with consistent structure and tag names as strings
 */
export async function fetchLinkById(linkId: string): Promise<Link> {
  const data = await authenticatedFetch(`/links/${linkId}`)
  return normalizeLinkResponse(data)
}

/**
 * Update an existing link's note and/or tags.
 *
 * @param linkId - The unique identifier of the link to update
 * @param params - Object containing note and/or tags to update
 * @returns A normalized Link object with the updated data
 */
export async function updateLink(linkId: string, params: UpdateLinkParams): Promise<Link> {
  const payload = {
    link: {
      note: params?.note,
      tag_names: params?.tags || [],
    },
  }

  const data = await authenticatedFetch(`/links/${linkId}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  })

  return normalizeLinkResponse(data)
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
  const json = await authenticatedFetch(`/tags${params}`)
  return json?.data?.tags ?? []
}
