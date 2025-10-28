import {
  createLink,
  deleteLink,
  fetchLinkById,
  fetchLinkByUrl,
  updateLink,
} from "../lib/linkRadarClient"

export default defineBackground(() => {
  // Listen for messages from content scripts or popup
  browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === "CREATE_LINK") {
      createLink(message.data)
        .then(() => sendResponse({ success: true }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true // Keep the message channel open for async response
    }

    if (message.type === "FETCH_LINK") {
      fetchLinkByUrl(message.url)
        .then(link => sendResponse({ success: true, link }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true // Keep the message channel open for async response
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

      return true // Keep the message channel open for async response
    }
  })
})
