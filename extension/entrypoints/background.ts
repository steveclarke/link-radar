import {
  createLink,
  deleteLink,
  fetchLinkById,
  fetchLinkByUrl,
  updateLink,
} from "../lib/linkRadarClient"

/**
 * Background script for LinkRadar browser extension.
 *
 * This service worker handles asynchronous API operations on behalf of the popup and content scripts.
 * It acts as a centralized message handler for all backend communication.
 *
 * Message Handler Pattern:
 * - Each handler processes a specific message type (CREATE_LINK, FETCH_LINK, etc.)
 * - All handlers make async API calls and send responses via sendResponse()
 * - IMPORTANT: We return `true` from each handler to keep the message channel open for async responses.
 *   This is required by the browser.runtime.onMessage API when using sendResponse() asynchronously.
 *   Without this, the message port would close before our async operations complete.
 *
 * Supported Message Types:
 * - CREATE_LINK: Save a new link to the backend
 * - FETCH_LINK: Find a link by URL
 * - FETCH_LINK_BY_ID: Get link details by ID
 * - UPDATE_LINK: Update link note and/or tags
 * - DELETE_LINK: Remove a link from the backend
 *
 * All responses follow the pattern: { success: boolean, data?, error? }
 */
export default defineBackground(() => {
  browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === "CREATE_LINK") {
      createLink(message.data)
        .then(() => sendResponse({ success: true }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true
    }

    if (message.type === "FETCH_LINK") {
      fetchLinkByUrl(message.url)
        .then(link => sendResponse({ success: true, link }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true
    }

    if (message.type === "FETCH_LINK_BY_ID") {
      fetchLinkById(message.linkId)
        .then(link => sendResponse({ success: true, link }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true
    }

    if (message.type === "UPDATE_LINK") {
      updateLink(message.linkId, message.data)
        .then(link => sendResponse({ success: true, link }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true
    }

    if (message.type === "DELETE_LINK") {
      deleteLink(message.linkId)
        .then(() => sendResponse({ success: true }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true
    }
  })
})
