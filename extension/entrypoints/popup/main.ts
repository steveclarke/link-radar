import './style.css';

console.log('Link Radar popup loaded');

interface TabInfo {
  title: string;
  url: string;
  favicon?: string;
}

// Get current tab details and display them
async function loadCurrentPageInfo() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (!tab || !tab.url) {
      showError('Unable to access current page');
      return;
    }

    const pageInfo: TabInfo = {
      title: tab.title || 'Untitled',
      url: tab.url,
      favicon: tab.favIconUrl
    };

    displayPageInfo(pageInfo);
  } catch (error) {
    console.error('Error getting tab info:', error);
    showError('Error loading page information');
  }
}

function displayPageInfo(info: TabInfo) {
  const container = document.getElementById('app');
  if (!container) return;

  container.innerHTML = `
    <div class="page-info">
      <h1>Link Radar</h1>

      <div class="current-page">
        <h2>Current Page</h2>
        <div class="page-details">
          ${info.favicon ? `<img src="${info.favicon}" class="favicon" alt="Site icon">` : ''}
          <div class="page-text">
            <div class="page-title">${info.title}</div>
            <div class="page-url">${info.url}</div>
          </div>
        </div>
      </div>

      <div class="actions">
        <button id="save-btn" class="save-button">Save This Link</button>
        <button id="copy-btn" class="copy-button">Copy URL</button>
      </div>

      <div class="notes-section">
        <label for="notes">Add a note (optional):</label>
        <textarea id="notes" placeholder="Add your thoughts about this link..."></textarea>
      </div>
    </div>
  `;

  // Add event listeners
  setupEventListeners(info);
}

function setupEventListeners(pageInfo: TabInfo) {
  const saveBtn = document.getElementById('save-btn');
  const copyBtn = document.getElementById('copy-btn');
  const notesTextarea = document.getElementById('notes') as HTMLTextAreaElement;

  saveBtn?.addEventListener('click', () => saveLink(pageInfo));
  copyBtn?.addEventListener('click', () => copyToClipboard(pageInfo.url));
}

async function saveLink(pageInfo: TabInfo) {
  const notesTextarea = document.getElementById('notes') as HTMLTextAreaElement;
  const notes = notesTextarea?.value || '';

  const linkData = {
    title: pageInfo.title,
    url: pageInfo.url,
    note: notes,
    saved_at: new Date().toISOString()
  };

  try {
    // Send to background script to save to backend
    const response = await chrome.runtime.sendMessage({
      type: 'SAVE_LINK',
      data: linkData
    });

    if (response.success) {
      showSuccess('Link saved successfully!');
      // Clear the notes
      const notesTextarea = document.getElementById('notes') as HTMLTextAreaElement;
      if (notesTextarea) notesTextarea.value = '';
    } else {
      showError('Failed to save link: ' + (response.error || 'Unknown error'));
    }
  } catch (error) {
    console.error('Error saving link:', error);
    showError('Error saving link');
  }
}

async function copyToClipboard(text: string) {
  try {
    await navigator.clipboard.writeText(text);
    showSuccess('URL copied to clipboard!');
  } catch (error) {
    console.error('Error copying to clipboard:', error);
    showError('Failed to copy URL');
  }
}

function showSuccess(message: string) {
  showMessage(message, 'success');
}

function showError(message: string) {
  showMessage(message, 'error');
}

function showMessage(message: string, type: 'success' | 'error') {
  // Remove existing messages
  const existingMessage = document.querySelector('.message');
  if (existingMessage) {
    existingMessage.remove();
  }

  const messageEl = document.createElement('div');
  messageEl.className = `message message-${type}`;
  messageEl.textContent = message;

  document.body.appendChild(messageEl);

  // Auto-remove after 3 seconds
  setTimeout(() => {
    messageEl.remove();
  }, 3000);
}

// Load page info when popup opens
loadCurrentPageInfo();

