export default defineBackground(() => {
  console.log('Link Radar background script loaded');

  // Listen for messages from content scripts or popup
  browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    console.log('Message received:', message);

    if (message.type === 'SAVE_LINK') {
      // Handle saving link to backend
      saveLinkToBackend(message.data)
        .then(() => sendResponse({ success: true }))
        .catch((error) => sendResponse({ success: false, error: error.message }));

      return true; // Keep the message channel open for async response
    }
  });
});

async function saveLinkToBackend(linkData: any) {
  // TODO: Implement API call to backend
  const backendUrl = 'http://localhost:3000/api/v1/links';

  const response = await fetch(backendUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(linkData),
  });

  if (!response.ok) {
    throw new Error(`Failed to save link: ${response.statusText}`);
  }

  return response.json();
}

