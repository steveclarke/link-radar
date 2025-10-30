import type { Tag } from "./tag"

/**
 * Link entity from backend API
 */
export interface Link {
  id: string
  url: string
  title: string
  note: string
  tags: Tag[]
}

/**
 * Parameters for creating a new link
 */
export interface LinkParams {
  url: string
  title: string
  note?: string
  tag_names?: string[]
}

/**
 * Parameters for updating an existing link
 */
export type UpdateLinkParams = Pick<LinkParams, "note" | "tag_names">

/**
 * Backend API response for single link
 */
export interface LinkApiResponse {
  data: {
    link: Link
  }
}

/**
 * Result from link operations (create, update, delete)
 */
export interface LinkResult {
  success: boolean
  error?: string
}
