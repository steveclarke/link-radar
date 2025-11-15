/**
 * Type definitions for data export and import operations.
 *
 * These types mirror the backend API responses from the DataController.
 * See backend spec.md section 7 for API contract details.
 */

/**
 * Export operation result from backend
 *
 * Returned by POST /api/v1/snapshot/export endpoint.
 * Contains file metadata and download URL.
 */
export interface ExportResult {
  /** Filename (not full path) - e.g., "linkradar-export-2025-11-12-143022-uuid.json" */
  file_path: string
  /** Total number of links exported (excludes ~temp~ tagged links) */
  link_count: number
  /** Total number of unique tags across all exported links */
  tag_count: number
  /** Relative URL for downloading the file - e.g., "/api/v1/snapshot/exports/filename.json" */
  download_url: string
}

/**
 * Backend API response wrapper for export
 *
 * Standard Rails API response format with nested data object.
 */
export interface ExportApiResponse {
  data: ExportResult
}

/**
 * Import operation result from backend
 *
 * Returned by POST /api/v1/snapshot/import endpoint.
 * Contains statistics about the import operation.
 */
export interface ImportResult {
  /** Number of links successfully imported (created or updated) */
  links_imported: number
  /** Number of links skipped due to duplicate URL (skip mode only) */
  links_skipped: number
  /** Number of new tags created during import */
  tags_created: number
  /** Number of existing tags reused (matched by case-insensitive name) */
  tags_reused: number
}

/**
 * Backend API response wrapper for import
 *
 * Standard Rails API response format with nested data object.
 */
export interface ImportApiResponse {
  data: ImportResult
}

/**
 * Import mode options
 *
 * - skip: Ignore duplicate URLs, keep existing data (safe default)
 * - update: Overwrite existing links with imported data (except created_at)
 */
export type ImportMode = "skip" | "update"
