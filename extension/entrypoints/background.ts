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
  const backendUrl = 'http://localhost:3000/api/v1/links';
  const apiKey = 'dev_api_key_change_in_production'; // From Rails config

  // Transform the data to match Rails API expectations
  const railsData = {
    link: {
      submitted_url: linkData.url,
      title: linkData.title,
      note: linkData.note
    }
  };

  const response = await fetch(backendUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify(railsData),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to save link: ${response.status} ${response.statusText} - ${errorText}`);
  }

  return response.json();
}

