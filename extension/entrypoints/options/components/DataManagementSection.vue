<script lang="ts" setup>
/**
 * Data Management section for export/import operations.
 * Only visible when developer mode is enabled.
 *
 * Provides:
 * - One-click export button (downloads JSON file)
 * - File upload for import with mode selection
 * - Toast notifications for feedback
 *
 * @component
 */
import type { ImportMode } from "../../../lib/types"
import { ref } from "vue"
import { exportLinks, importLinks } from "../../../lib/apiClient"
import { useNotification } from "../../../lib/composables/useNotification"
import { getActiveEnvironmentConfig } from "../../../lib/settings"

const { showSuccess, showError } = useNotification()

// UI state
const isExporting = ref(false)
const isImporting = ref(false)
const selectedMode = ref<ImportMode>("skip")
const selectedFile = ref<File | null>(null)

/**
 * Handle export button click
 *
 * Flow:
 * 1. Call backend export API
 * 2. Get download URL from response
 * 3. Trigger browser download
 * 4. Show success toast with counts
 */
async function handleExport() {
  isExporting.value = true
  try {
    const result = await exportLinks()

    // Fetch the file with authentication, then trigger download
    const config = await getActiveEnvironmentConfig()
    // Extract base URL (protocol + domain) from config URL
    // e.g., "https://api.linkradar.app/api/v1" → "https://api.linkradar.app"
    const baseUrl = new URL(config.url).origin
    const downloadUrl = `${baseUrl}${result.download_url}`

    // Fetch file with Authorization header
    const response = await fetch(downloadUrl, {
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
      },
    })

    if (!response.ok) {
      throw new Error(`Download failed: ${response.status} ${response.statusText}`)
    }

    // Create blob and trigger download
    const blob = await response.blob()
    const objectUrl = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = objectUrl
    link.download = result.file_path
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(objectUrl)

    showSuccess(`Exported ${result.link_count} links`)
  }
  catch (error) {
    console.error("Export error:", error)
    const message = error instanceof Error ? error.message : "Unknown error"
    showError(`Export failed: ${message}`)
  }
  finally {
    isExporting.value = false
  }
}

/**
 * Handle file selection
 *
 * Just captures the selected file - actual import happens when user clicks Import button
 */
function handleFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]

  if (file) {
    selectedFile.value = file
  }
}

/**
 * Handle import button click
 *
 * Flow:
 * 1. Call backend import API with selected file and mode
 * 2. Show success toast with statistics
 * 3. Clear selected file for next import
 */
async function handleImport() {
  if (!selectedFile.value)
    return

  isImporting.value = true
  try {
    const result = await importLinks(selectedFile.value, selectedMode.value)

    showSuccess(
      `Imported ${result.links_imported} links, ${result.tags_created} new tags`,
    )

    // Clear selected file and input
    selectedFile.value = null
    // Reset the file input so same file can be selected again
    const fileInput = document.querySelector("input[type=\"file\"]") as HTMLInputElement
    if (fileInput)
      fileInput.value = ""
  }
  catch (error) {
    console.error("Import error:", error)
    const message = error instanceof Error ? error.message : "Unknown error"
    showError(`Import failed: ${message}`)

    // Clear selected file on error too
    selectedFile.value = null
    const fileInput = document.querySelector("input[type=\"file\"]") as HTMLInputElement
    if (fileInput)
      fileInput.value = ""
  }
  finally {
    isImporting.value = false
  }
}
</script>

<template>
  <div class="bg-white border border-slate-200 rounded-lg p-6">
    <h2 class="text-lg font-semibold text-slate-900 mb-2">
      Data Management
    </h2>
    <p class="text-sm text-slate-600 mb-6">
      Export your links to JSON file or import from previous exports. Links tagged with ~temp~ are excluded from exports.
    </p>

    <div class="space-y-6">
      <!-- Export Section -->
      <div>
        <h3 class="text-sm font-medium text-slate-900 mb-3">
          Export
        </h3>
        <button
          :disabled="isExporting"
          class="px-4 py-2 border-none rounded-md text-sm font-medium bg-brand-600 text-white cursor-pointer transition-colors hover:bg-brand-700 disabled:opacity-60 disabled:cursor-not-allowed"
          @click="handleExport"
        >
          {{ isExporting ? 'Exporting...' : 'Export All Links' }}
        </button>
      </div>

      <!-- Import Section -->
      <div>
        <h3 class="text-sm font-medium text-slate-900 mb-3">
          Import
        </h3>

        <!-- Mode Selection -->
        <div class="mb-3">
          <label class="block text-sm text-slate-700 mb-2">
            Import Mode
          </label>
          <select
            v-model="selectedMode"
            :disabled="isImporting"
            class="block w-full max-w-xs px-3 py-2 bg-white border border-slate-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-brand-600 focus:border-brand-600 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            <option value="skip">
              Skip duplicates (keep existing data)
            </option>
            <option value="update">
              Update existing (overwrite with import data)
            </option>
          </select>
          <p class="mt-1 text-xs text-slate-500">
            <span v-if="selectedMode === 'skip'">
              Safe default - existing links unchanged
            </span>
            <span v-else>
              Overwrites existing links (except timestamps)
            </span>
          </p>
        </div>

        <!-- File Input and Import Button -->
        <div class="space-y-3">
          <div>
            <label
              class="inline-flex items-center px-4 py-2 border border-slate-300 rounded-md text-sm font-medium text-slate-700 bg-white cursor-pointer transition-colors hover:bg-slate-50 disabled:opacity-60 disabled:cursor-not-allowed"
              :class="{ 'opacity-60 cursor-not-allowed': isImporting }"
            >
              <span>Choose File</span>
              <input
                type="file"
                accept=".json,application/json"
                :disabled="isImporting"
                class="hidden"
                @change="handleFileSelected"
              >
            </label>
            <p class="mt-1 text-xs text-slate-500">
              Select LinkRadar export JSON file
            </p>
          </div>

          <!-- Show selected file and import button -->
          <div v-if="selectedFile" class="pt-2">
            <p class="text-sm text-slate-700 mb-3">
              <span class="font-medium">Selected:</span> {{ selectedFile.name }}
            </p>
            <button
              :disabled="isImporting"
              class="px-4 py-2 border-none rounded-md text-sm font-medium bg-brand-600 text-white cursor-pointer transition-colors hover:bg-brand-700 disabled:opacity-60 disabled:cursor-not-allowed"
              @click="handleImport"
            >
              {{ isImporting ? 'Importing...' : 'Import' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
