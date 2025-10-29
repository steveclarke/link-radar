/**
 * Tag entity from backend API
 */
export interface Tag {
  id: string
  name: string
  slug: string
  usage_count: number
}

/**
 * Backend API response for tag list
 */
export interface TagsApiResponse {
  data: {
    tags: Tag[]
  }
}
