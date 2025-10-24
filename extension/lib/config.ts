/**
 * Configuration constants for the Link Radar extension
 */

/**
 * Backend API base URL (without endpoint path)
 * Append specific endpoints like `/links` when making requests
 * Can be overridden at build time using VITE_BACKEND_URL environment variable
 * Example: VITE_BACKEND_URL=http://localhost:3001/api/v1 pnpm build
 */
export const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || "http://localhost:3000/api/v1"

/**
 * Chrome storage keys
 */
export const STORAGE_KEYS = {
  API_KEY: "linkradar_api_key",
} as const
