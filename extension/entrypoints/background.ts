import {
  checkLinkExists,
  deleteLink,
  getLink,
  saveLink,
  updateLink,
} from "../lib/linkRadarClient"

export default defineBackground(() => {
  // Listen for messages from content scripts or popup
  browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === "SAVE_LINK") {
      saveLink(message.data)
        .then(() => sendResponse({ success: true }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true // Keep the message channel open for async response
    }

    if (message.type === "CHECK_LINK_EXISTS") {
      // Check if a link with this URL already exists
      checkLinkExists(message.url)
        .then(result => sendResponse({ success: true, ...result }))
        .catch(error => sendResponse({ success: false, error: error.message }))

      return true // Keep the message channel open for async response
    }

    if (message.type === "GET_LINK_DETAILS") {
      getLink(message.linkId)
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
