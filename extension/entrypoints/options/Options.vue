<script lang="ts" setup>
import { ref, onMounted } from 'vue';
import { STORAGE_KEYS } from '../../lib/config';

const apiKey = ref('');
const showApiKey = ref(false);
const message = ref<{ text: string; type: 'success' | 'error' } | null>(null);
const isSaving = ref(false);

async function loadSettings() {
  try {
    const result = await chrome.storage.sync.get(STORAGE_KEYS.API_KEY);
    if (result[STORAGE_KEYS.API_KEY]) {
      apiKey.value = result[STORAGE_KEYS.API_KEY];
    }
  } catch (error) {
    console.error('Error loading settings:', error);
    showError('Failed to load settings');
  }
}

async function saveSettings() {
  if (!apiKey.value.trim()) {
    showError('Please enter an API key');
    return;
  }

  isSaving.value = true;
  try {
    await chrome.storage.sync.set({
      [STORAGE_KEYS.API_KEY]: apiKey.value.trim()
    });
    showSuccess('Settings saved successfully!');
  } catch (error) {
    console.error('Error saving settings:', error);
    showError('Failed to save settings');
  } finally {
    isSaving.value = false;
  }
}

function toggleShowApiKey() {
  showApiKey.value = !showApiKey.value;
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
  loadSettings();
});
</script>

<template>
  <div class="settings-container">
    <div class="settings-header">
      <h1>Link Radar Settings</h1>
      <p class="subtitle">Configure your Link Radar extension</p>
    </div>

    <div class="settings-content">
      <div class="setting-section">
        <h2>API Configuration</h2>
        <p class="help-text">
          Enter your Link Radar API key to enable link saving. You can find this in your backend configuration.
        </p>

        <div class="form-group">
          <label for="api-key">API Key</label>
          <div class="input-with-toggle">
            <input
              id="api-key"
              v-model="apiKey"
              :type="showApiKey ? 'text' : 'password'"
              placeholder="Enter your API key"
              class="api-key-input"
            />
            <button
              type="button"
              @click="toggleShowApiKey"
              class="toggle-visibility-btn"
              :title="showApiKey ? 'Hide API key' : 'Show API key'"
            >
              {{ showApiKey ? '👁️' : '👁️‍🗨️' }}
            </button>
          </div>
        </div>

        <button
          @click="saveSettings"
          :disabled="isSaving"
          class="save-button"
        >
          {{ isSaving ? 'Saving...' : 'Save Settings' }}
        </button>
      </div>

      <div class="info-section">
        <h3>Backend Setup</h3>
        <p>
          To use Link Radar, you need to have the backend API running.
          By default, the extension expects the API to be available at:
        </p>
        <code class="backend-url">http://localhost:3000/api/v1/links</code>
        <p class="note">
          For production use, the backend URL can be configured at build time
          using the <code>VITE_BACKEND_URL</code> environment variable.
        </p>
      </div>
    </div>

    <div v-if="message" :class="['message', `message-${message.type}`]">
      {{ message.text }}
    </div>
  </div>
</template>

<style scoped>
.settings-container {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
}

.settings-header {
  margin-bottom: 32px;
}

.settings-header h1 {
  margin: 0 0 8px 0;
  font-size: 32px;
  color: #1a1a1a;
}

.subtitle {
  margin: 0;
  font-size: 16px;
  color: #666;
}

.settings-content {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.setting-section,
.info-section {
  background: white;
  border-radius: 8px;
  padding: 24px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.setting-section h2,
.info-section h3 {
  margin: 0 0 16px 0;
  font-size: 20px;
  color: #1a1a1a;
}

.help-text {
  margin: 0 0 20px 0;
  font-size: 14px;
  color: #666;
  line-height: 1.5;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  font-size: 14px;
  font-weight: 500;
  color: #333;
  margin-bottom: 8px;
}

.input-with-toggle {
  display: flex;
  gap: 8px;
  align-items: stretch;
}

.api-key-input {
  flex: 1;
  padding: 10px 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 14px;
  font-family: 'Monaco', 'Courier New', monospace;
  transition: border-color 0.2s;
}

.api-key-input:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
}

.toggle-visibility-btn {
  padding: 0 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: white;
  cursor: pointer;
  font-size: 18px;
  transition: background-color 0.2s;
}

.toggle-visibility-btn:hover {
  background: #f8f9fa;
}

.save-button {
  padding: 10px 24px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  background: #007bff;
  color: white;
  cursor: pointer;
  transition: background-color 0.2s;
}

.save-button:hover:not(:disabled) {
  background: #0056b3;
}

.save-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.info-section p {
  margin: 0 0 12px 0;
  font-size: 14px;
  color: #666;
  line-height: 1.5;
}

.backend-url {
  display: block;
  padding: 12px;
  background: #f8f9fa;
  border: 1px solid #e9ecef;
  border-radius: 4px;
  font-family: 'Monaco', 'Courier New', monospace;
  font-size: 13px;
  color: #333;
  margin: 12px 0;
}

.note {
  font-size: 13px;
  color: #888;
  font-style: italic;
}

code {
  padding: 2px 6px;
  background: #f8f9fa;
  border: 1px solid #e9ecef;
  border-radius: 3px;
  font-family: 'Monaco', 'Courier New', monospace;
  font-size: 12px;
}

.message {
  position: fixed;
  top: 24px;
  right: 24px;
  padding: 12px 16px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  z-index: 1000;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
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

