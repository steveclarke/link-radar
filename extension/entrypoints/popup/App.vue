<script lang="ts" setup>
import { ref, onMounted } from 'vue';
import { useClipboard } from '@vueuse/core';

interface TabInfo {
  title: string;
  url: string;
  favicon?: string;
}

const pageInfo = ref<TabInfo | null>(null);
const notes = ref('');
const message = ref<{ text: string; type: 'success' | 'error' } | null>(null);

// Use VueUse clipboard composable
const { copy, isSupported } = useClipboard();

async function loadCurrentPageInfo() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (!tab || !tab.url) {
      showError('Unable to access current page');
      return;
    }

    pageInfo.value = {
      title: tab.title || 'Untitled',
      url: tab.url,
      favicon: tab.favIconUrl
    };
  } catch (error) {
    console.error('Error getting tab info:', error);
    showError('Error loading page information');
  }
}

async function saveLink() {
  if (!pageInfo.value) return;

  const linkData = {
    title: pageInfo.value.title,
    url: pageInfo.value.url,
    note: notes.value,
    saved_at: new Date().toISOString()
  };

  try {
    const response = await chrome.runtime.sendMessage({
      type: 'SAVE_LINK',
      data: linkData
    });

    if (response.success) {
      showSuccess('Link saved successfully!');
      notes.value = '';
    } else {
      showError('Failed to save link: ' + (response.error || 'Unknown error'));
    }
  } catch (error) {
    console.error('Error saving link:', error);
    showError('Error saving link');
  }
}

async function copyToClipboard() {
  if (!pageInfo.value || !isSupported.value) return;

  try {
    await copy(pageInfo.value.url);
    showSuccess('URL copied to clipboard!');
  } catch (error) {
    console.error('Error copying to clipboard:', error);
    showError('Failed to copy URL');
  }
}

function showSuccess(text: string) {
  showMessage(text, 'success');
}

function showError(text: string) {
  showMessage(text, 'error');
}

function showMessage(text: string, type: 'success' | 'error') {
  message.value = { text, type };
  setTimeout(() => {
    message.value = null;
  }, 3000);
}

onMounted(() => {
  loadCurrentPageInfo();
});
</script>

<template>
  <div class="page-info">
    <div class="header">
      <h1>Link Radar</h1>
      <span class="vue-badge">⚡ Vue 3</span>
    </div>

    <div v-if="pageInfo" class="current-page">
      <h2>Current Page</h2>
      <div class="page-details">
        <img v-if="pageInfo.favicon" :src="pageInfo.favicon" class="favicon" alt="Site icon">
        <div class="page-text">
          <div class="page-title">{{ pageInfo.title }}</div>
          <div class="page-url">{{ pageInfo.url }}</div>
        </div>
      </div>
    </div>

    <div class="actions">
      <button @click="saveLink" class="save-button">Save This Link</button>
      <button @click="copyToClipboard" class="copy-button">Copy URL</button>
    </div>

    <div class="notes-section">
      <label for="notes">Add a note (optional):</label>
      <textarea
        id="notes"
        v-model="notes"
        placeholder="Add your thoughts about this link..."
      ></textarea>
    </div>

    <div v-if="message" :class="['message', `message-${message.type}`]">
      {{ message.text }}
    </div>
  </div>
</template>

<style scoped>
body {
  width: 400px;
  min-height: 300px;
  margin: 0;
  padding: 16px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  background: #f8f9fa;
}

.page-info {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.header {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

h1 {
  margin: 0;
  font-size: 24px;
  color: #1a1a1a;
}

.vue-badge {
  font-size: 12px;
  background: linear-gradient(135deg, #42b883 0%, #35495e 100%);
  color: white;
  padding: 4px 8px;
  border-radius: 12px;
  font-weight: 600;
  letter-spacing: 0.5px;
}

h2 {
  margin: 0 0 8px 0;
  font-size: 16px;
  color: #333;
}

.current-page {
  background: white;
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.page-details {
  display: flex;
  align-items: flex-start;
  gap: 8px;
}

.favicon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
  margin-top: 2px;
}

.page-text {
  flex: 1;
  min-width: 0;
}

.page-title {
  font-weight: 500;
  color: #1a1a1a;
  margin-bottom: 4px;
  line-height: 1.3;
  word-wrap: break-word;
}

.page-url {
  font-size: 12px;
  color: #666;
  word-break: break-all;
  line-height: 1.2;
}

.actions {
  display: flex;
  gap: 8px;
}

.save-button, .copy-button {
  flex: 1;
  padding: 8px 12px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 0.2s;
}

.save-button {
  background: #007bff;
  color: white;
}

.save-button:hover {
  background: #0056b3;
}

.copy-button {
  background: #6c757d;
  color: white;
}

.copy-button:hover {
  background: #545b62;
}

.notes-section {
  background: white;
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.notes-section label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: #333;
  margin-bottom: 8px;
}

.notes-section textarea {
  width: 100%;
  min-height: 60px;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 14px;
  font-family: inherit;
  resize: vertical;
  box-sizing: border-box;
}

.notes-section textarea:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.25);
}

.message {
  position: fixed;
  top: 16px;
  left: 16px;
  right: 16px;
  padding: 8px 12px;
  border-radius: 4px;
  font-size: 14px;
  font-weight: 500;
  z-index: 1000;
}

.message-success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.message-error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}
</style>

