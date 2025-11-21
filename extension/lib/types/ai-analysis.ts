/**
 * AI Analysis Type Definitions
 *
 * These types define the contracts for AI-powered link analysis:
 * - Request payload sent to backend
 * - Response structure from backend
 * - Client-side state management
 * - Content extraction results
 *
 * All types match backend API contracts defined in spec.md#3.2 and spec.md#3.3
 */

/**
 * Analysis request payload sent to backend
 *
 * Matches backend POST /api/v1/links/analyze request contract (spec.md#3.2)
 */
export interface AnalysisRequest {
  /** Page URL (HTTP/HTTPS only) */
  url: string

  /** Main article text extracted via Readability (max 50,000 chars) */
  content: string

  /** Page title (from og:title, <title>, or h1) */
  title: string

  /** Meta description (from og:description or meta description tag) */
  description: string

  /** Author information (from meta author or og:article:author) - optional */
  author?: string
}

/**
 * Individual tag suggestion from AI
 *
 * Each tag includes:
 * - name: Tag text (Title Case preferred, e.g., "JavaScript")
 * - exists: Whether tag exists in user's collection (for visual styling)
 */
export interface SuggestedTag {
  /** Tag name in Title Case or lowercase */
  name: string

  /** true if tag exists in user's Tag collection, false if new */
  exists: boolean
}

/**
 * Analysis response from backend
 *
 * Matches backend response contract (spec.md#3.3)
 * Wrapped in `data` object per existing API conventions
 */
export interface AnalysisResponse {
  data: {
    /** AI-generated note (1-2 sentences explaining value) */
    suggested_note: string

    /** AI-generated tag suggestions (typically 3-7 tags) */
    suggested_tags: SuggestedTag[]
  }
}

/**
 * Analysis state for UI management
 *
 * Tracks the complete lifecycle of an analysis request:
 * - Loading state (isAnalyzing)
 * - Error state (error)
 * - Success state (suggestions)
 * - User selections (selectedTagNames)
 *
 * Used by useAiAnalysis composable and consumed by UI components
 */
export interface AnalysisState {
  /** true when analysis API call is in progress */
  isAnalyzing: boolean

  /** Error message if analysis failed, null if no error */
  error: string | null

  /** AI-suggested note text, null if no suggestion yet */
  suggestedNote: string | null

  /** Array of AI-suggested tags with existence indicators */
  suggestedTags: SuggestedTag[]

  /** Set of tag names user has selected (for O(1) toggle checks) */
  selectedTagNames: Set<string>
}
