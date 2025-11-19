/**
 * Content Extraction Utilities
 *
 * Extracts page content and metadata using @mozilla/readability.
 * Readability is Mozilla's article extraction library - parses page DOM
 * and returns clean article text, removing ads, sidebars, and navigation.
 *
 * Extraction strategy:
 * - Clone DOM before passing to Readability (it modifies the document)
 * - Use fallback chains for title and description
 * - Extract author from meta tags when available
 * - Truncate content to 50,000 characters (backend limit per spec.md#3.2)
 *
 * Handles edge cases:
 * - Pages with no readable content (returns empty string)
 * - Missing metadata (uses sensible defaults)
 * - Multiple meta tag formats (og: tags, standard meta tags)
 */

import { Readability } from "@mozilla/readability"

/**
 * Result of content extraction
 *
 * Contains all data needed for AI analysis:
 * - Cleaned article text
 * - Page title (with fallback chain)
 * - Meta description (optional)
 * - Author info (optional)
 */
export interface ExtractedContent {
  /** Main article text from Readability.parse() (truncated to 50K chars) */
  content: string

  /** Page title (og:title > <title> > h1 > "Untitled") */
  title: string

  /** Meta description (og:description > meta description > empty string) */
  description: string

  /** Author from meta tags (optional) */
  author?: string

  /** Full page URL for context */
  url: string
}

/**
 * Maximum content length before truncation (matches backend limit)
 * Backend validates at 50,000 chars (spec.md#3.2)
 * Extension truncates before sending for network efficiency
 */
const MAX_CONTENT_LENGTH = 50_000

/**
 * Extract page content using Readability
 *
 * Extracts both article content and metadata for AI analysis. Content is kept
 * as structured HTML (not plain text) to preserve semantic information for analysis.
 * Works on any page type - articles, apps, docs, etc.
 *
 * Process:
 * 1. Clone document (Readability modifies DOM)
 * 2. Parse with Readability to extract content and metadata
 * 3. Use Readability's metadata, fall back to DOM queries if needed
 * 4. Truncate content to MAX_CONTENT_LENGTH
 * 5. Return structured result
 *
 * @returns Extraction result with content and metadata
 *
 * @example
 *   const extracted = extractPageContent()
 *   console.log(extracted.title)
 *   console.log(extracted.content.length)
 */
export function extractPageContent(): ExtractedContent {
  // Clone document for Readability (it modifies the DOM)
  const documentClone = document.cloneNode(true) as Document

  // Extract content and metadata using Readability
  const reader = new Readability(documentClone)
  const article = reader.parse()

  // Use Readability's extracted data as primary source, fall back to DOM queries
  let content = article?.content || ""
  const title = article?.title || extractTitle()
  const description = article?.excerpt || extractDescription()
  const author = article?.byline || extractAuthor()

  // Truncate content to backend limit (spec.md#3.2)
  if (content.length > MAX_CONTENT_LENGTH) {
    content = content.substring(0, MAX_CONTENT_LENGTH)
  }

  return {
    content,
    title,
    description,
    author,
    url: window.location.href,
  }
}

/**
 * Extract title from page using meta tags
 *
 * Fallback chain: og:title > <title> > first <h1> > "Untitled"
 *
 * @returns Page title with fallback
 */
function extractTitle(): string {
  const ogTitle = document.querySelector("meta[property=\"og:title\"]")
    ?.getAttribute("content")
  const titleTag = document.title
  const firstH1 = document.querySelector("h1")?.textContent
  return (ogTitle || titleTag || firstH1 || "Untitled").trim()
}

/**
 * Extract description from page using meta tags
 *
 * Fallback chain: og:description > meta description > ""
 *
 * @returns Page description with fallback
 */
function extractDescription(): string {
  const ogDescription = document.querySelector("meta[property=\"og:description\"]")
    ?.getAttribute("content")
  const metaDescription = document.querySelector("meta[name=\"description\"]")
    ?.getAttribute("content")
  return (ogDescription || metaDescription || "").trim()
}

/**
 * Extract author from page using meta tags
 *
 * Fallback chain: meta author > og:article:author > undefined
 *
 * @returns Author name or undefined if not found
 */
function extractAuthor(): string | undefined {
  const metaAuthor = document.querySelector("meta[name=\"author\"]")
    ?.getAttribute("content")
  const ogAuthor = document.querySelector("meta[property=\"og:article:author\"]")
    ?.getAttribute("content")
  return (metaAuthor || ogAuthor)?.trim()
}
