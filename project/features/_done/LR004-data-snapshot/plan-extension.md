# LR004 - Data Snapshot & Import System: Extension Plan

## Overview

This plan implements the browser extension UI for data export and import functionality. The implementation integrates with the backend API to provide one-click export and file upload import with visual feedback.

**What we're building:**
- TypeScript type definitions for export/import operations
- API client methods for calling backend endpoints
- DataManagementSection component with export button and import file picker
- Integration into options page developer mode
- Toast notifications for user feedback

**Key components:**
- `lib/types/dataExport.ts` - Type definitions for API responses
- `lib/apiClient.ts` - Export/import API methods
- `entrypoints/options/components/DataManagementSection.vue` - UI component
- Integration with existing useNotification composable

**Sequencing logic:**
1. Prerequisites first (verify backend API ready, update Link type)
2. Type definitions before API client (type safety)
3. API client before UI component (component calls API methods)
4. Integration into existing developer panel
5. Manual testing to verify end-to-end flow

**Cross-references:**
- Technical spec: [spec.md](./spec.md) sections 7 (API), 8 (Extension)
- Requirements: [requirements.md](./requirements.md) section 5 (UX)
- Backend plan: [plan-backend.md](./plan-backend.md)

---

## Table of Contents

1. [Phase 1: Prerequisites & Type Definitions](#1-phase-1-prerequisites--type-definitions)
2. [Phase 2: API Client Methods](#2-phase-2-api-client-methods)
3. [Phase 3: UI Component](#3-phase-3-ui-component)
4. [Phase 4: Integration & Testing](#4-phase-4-integration--testing)
5. [Phase 5: Documentation](#5-phase-5-documentation)

---

## 1. Phase 1: Prerequisites & Type Definitions

**Implements:** [spec.md#8.2](./spec.md#82-typescript-type-definitions)

**Justification:** Backend API must be complete and deployed before extension can call it. Type definitions provide type safety for API integration.

### 1.1. Verify Backend Prerequisites

- [ ] Verify backend API endpoints are deployed and accessible:
  - `POST /api/v1/snapshot/export`
  - `GET /api/v1/snapshot/exports/:filename`
  - `POST /api/v1/snapshot/import`
- [ ] Test endpoints via curl or Bruno to confirm they work
- [ ] Verify `submitted_url` field removed from Link model (schema simplification)

### 1.2. Update Link Type Definition

- [ ] Update `extension/lib/types/link.ts` to remove `submitted_url` field

The Link interface should now only have `url` (not `submitted_url`):

```typescript
export interface Link {
  id: string
  url: string        // Only url field (submitted_url removed)
  title: string
  note: string
  tags: Tag[]
}
```

This aligns with the backend schema simplification from Phase 1 of the backend plan.

### 1.3. Create Data Export Type Definitions

- [ ] Create file: `extension/lib/types/dataExport.ts`

```typescript
/**
 * Type definitions for data export and import operations.
 *
 * These types mirror the backend API responses from the DataController.
 * See backend spec.md section 7 for API contract details.
 */

/**
 * Export operation result from backend
 *
 * Returned by POST /api/v1/data/export endpoint.
 * Contains file metadata and download URL.
 */
export interface ExportResult {
  /** Filename (not full path) - e.g., "linkradar-export-2025-11-12-143022-uuid.json" */
  file_path: string
  /** Total number of links exported (excludes ~temp~ tagged links) */
  link_count: number
  /** Total number of unique tags across all exported links */
  tag_count: number
  /** Relative URL for downloading the file - e.g., "/api/v1/data/exports/filename.json" */
  download_url: string
}

/**
 * Backend API response wrapper for export
 *
 * Standard Rails API response format with nested data object.
 */
export interface ExportApiResponse {
  data: ExportResult
}

/**
 * Import operation result from backend
 *
 * Returned by POST /api/v1/data/import endpoint.
 * Contains statistics about the import operation.
 */
export interface ImportResult {
  /** Number of links successfully imported (created or updated) */
  links_imported: number
  /** Number of links skipped due to duplicate URL (skip mode only) */
  links_skipped: number
  /** Number of new tags created during import */
  tags_created: number
  /** Number of existing tags reused (matched by case-insensitive name) */
  tags_reused: number
}

/**
 * Backend API response wrapper for import
 *
 * Standard Rails API response format with nested data object.
 */
export interface ImportApiResponse {
  data: ImportResult
}

/**
 * Import mode options
 *
 * - skip: Ignore duplicate URLs, keep existing data (safe default)
 * - update: Overwrite existing links with imported data (except created_at)
 */
export type ImportMode = "skip" | "update"
```

- [ ] Update `extension/lib/types/index.ts` to export new types:

```typescript
export * from "./dataExport"
export * from "./link"
export * from "./notification"
export * from "./tab"
export * from "./tag"
```

---

## 2. Phase 2: API Client Methods

**Implements:** [spec.md#8.3](./spec.md#83-api-client-methods)

**Justification:** API client provides reusable HTTP methods for export/import operations. Encapsulates backend communication details and error handling.

### 2.1. Add Export Method

- [ ] Update `extension/lib/apiClient.ts` to add export method

Add this method after existing API methods (follow the established `authenticatedFetch` pattern):

```typescript
/**
 * Export all links to JSON file
 *
 * Calls POST /api/v1/snapshot/export to generate export file on backend.
 * Returns metadata and download URL for retrieving the file.
 *
 * Links tagged with ~temp~ are excluded from exports.
 *
 * @returns Export result with download URL and counts
 * @throws Error if API request fails
 */
export async function exportLinks(): Promise<ExportResult> {
  const response = await authenticatedFetch("/snapshot/export", {
    method: "POST",
  }) as ExportApiResponse

  return response.data
}
```

### 2.2. Add Import Method

- [ ] Add import method to `extension/lib/apiClient.ts`

```typescript
/**
 * Import links from uploaded file
 *
 * Calls POST /api/v1/snapshot/import with multipart form data.
 * Accepts LinkRadar native JSON format only.
 *
 * Import modes:
 * - skip (default): Ignore duplicate URLs, keep existing data
 * - update: Overwrite existing links with imported data (except created_at)
 *
 * Entire import is wrapped in transaction - any error rolls back all changes.
 *
 * @param file - JSON file to import (LinkRadar format)
 * @param mode - Import mode: "skip" or "update" (defaults to "skip")
 * @returns Import statistics (links imported/skipped, tags created/reused)
 * @throws Error if API request fails or file is invalid
 */
export async function importLinks(
  file: File,
  mode: ImportMode = "skip",
): Promise<ImportResult> {
  const config = await getActiveEnvironmentConfig()
  const fullUrl = `${config.url}/snapshot/import`

  // Build FormData for multipart upload
  // Note: Content-Type header must NOT be set manually - browser sets it with boundary
  const formData = new FormData()
  formData.append("file", file)
  formData.append("mode", mode)

  const response = await fetch(fullUrl, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${config.apiKey}`,
      // Note: Do NOT set Content-Type - browser handles it for FormData
    },
    body: formData,
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Import failed: ${response.status} ${response.statusText} - ${errorText}`)
  }

  const result = await response.json() as ImportApiResponse
  return result.data
}
```

- [ ] Add import for new types at top of file:

```typescript
import type {
  ExportResult,
  ExportApiResponse,
  ImportResult,
  ImportApiResponse,
  ImportMode,
} from "./types"
```

---

## 3. Phase 3: UI Component

**Implements:** [spec.md#8.4](./spec.md#84-ui-component-structure), [requirements.md#5.1-5.2](./requirements.md#51-extension-interface)

**Justification:** UI component provides the user interface for export/import operations. Follows existing Vue component patterns and integrates with options page developer mode.

### 3.1. Create DataManagementSection Component

- [ ] Create file: `extension/entrypoints/options/components/DataManagementSection.vue`

```vue
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
import { useNotification } from "../../../lib/composables/useNotification"
import { exportLinks, importLinks } from "../../../lib/apiClient"
import { getActiveEnvironmentConfig } from "../../../lib/settings"

const { showSuccess, showError } = useNotification()

// UI state
const isExporting = ref(false)
const isImporting = ref(false)
const selectedMode = ref<ImportMode>("skip")

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

    // Trigger browser download using the download URL
    const config = await getActiveEnvironmentConfig()
    const downloadUrl = `${config.url}${result.download_url}`

    // Create hidden link and trigger click to download
    const link = document.createElement("a")
    link.href = downloadUrl
    link.download = result.file_path
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)

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
 * Handle file selection for import
 *
 * Flow:
 * 1. User selects file from picker
 * 2. Call backend import API with file and mode
 * 3. Show success toast with statistics
 * 4. Clear file input for next import
 */
async function handleImport(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]

  if (!file) return

  isImporting.value = true
  try {
    const result = await importLinks(file, selectedMode.value)

    showSuccess(
      `Imported ${result.links_imported} links, ${result.tags_created} new tags`,
    )

    // Clear file input so same file can be selected again
    input.value = ""
  }
  catch (error) {
    console.error("Import error:", error)
    const message = error instanceof Error ? error.message : "Unknown error"
    showError(`Import failed: ${message}`)

    // Clear file input on error too
    input.value = ""
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

        <!-- File Input -->
        <div>
          <label
            class="inline-flex items-center px-4 py-2 border border-slate-300 rounded-md text-sm font-medium text-slate-700 bg-white cursor-pointer transition-colors hover:bg-slate-50 disabled:opacity-60 disabled:cursor-not-allowed"
            :class="{ 'opacity-60 cursor-not-allowed': isImporting }"
          >
            <span>{{ isImporting ? 'Importing...' : 'Choose File' }}</span>
            <input
              type="file"
              accept=".json,application/json"
              :disabled="isImporting"
              class="hidden"
              @change="handleImport"
            >
          </label>
          <p class="mt-1 text-xs text-slate-500">
            Select LinkRadar export JSON file
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
```

- [ ] Verify component follows existing Vue/Tailwind patterns from options page

### 3.2. Integrate into SettingsForm

- [ ] Update `extension/entrypoints/options/components/SettingsForm.vue`

Add import at top of script section:

```typescript
import DataManagementSection from "./DataManagementSection.vue"
```

Add component in developer mode section (after EnvironmentConfig):

```vue
<!-- Environment Configuration (only visible in developer mode) -->
<div v-if="isDeveloperMode" class="mt-8 pt-8 border-t border-slate-200">
  <EnvironmentConfig
    v-model="draftEnvironment"
    v-model:environment-configs="draftEnvironmentConfigs"
    v-model:show-api-keys="showApiKeys"
  />
</div>

<!-- Data Management (only visible in developer mode) -->
<div v-if="isDeveloperMode" class="mt-8 pt-8 border-t border-slate-200">
  <DataManagementSection />
</div>

<!-- Save Button -->
<div class="mt-8 flex justify-end">
  <!-- ... existing save button ... -->
</div>
```

- [ ] Verify component appears in developer mode only

---

## 4. Phase 4: Integration & Testing

**Implements:** [requirements.md#9.1](./requirements.md#91-acceptance-criteria)

**Justification:** Manual testing validates the complete user flow and verifies backend integration. Focus on happy path and common error scenarios.

### 4.1. Manual Testing - Export Flow

- [ ] Start extension in development mode
- [ ] Open options page
- [ ] Enable Developer Mode toggle (top-right corner)
- [ ] Scroll to "Data Management" section
- [ ] Click "Export All Links" button
- [ ] Verify:
  - Button shows "Exporting..." during operation
  - Browser download triggers automatically
  - Downloaded file has timestamped name with UUID
  - Toast notification shows "Exported X links"
  - File contains valid JSON with links and tags
- [ ] Test with zero links:
  - Delete all links
  - Export again
  - Verify file created with empty links array

### 4.2. Manual Testing - Import Flow (Skip Mode)

- [ ] Start with some existing links in database
- [ ] Export current data (creates baseline)
- [ ] Manually edit notes or tags in database
- [ ] In extension, select "Skip duplicates" mode
- [ ] Click "Choose File" and select the baseline export
- [ ] Verify:
  - Button shows "Importing..." during operation
  - Toast notification shows "Imported X links, Y new tags"
  - Existing links unchanged (edits preserved)
  - Only new links from export are imported
  - File input cleared after import (can select same file again)

### 4.3. Manual Testing - Import Flow (Update Mode)

- [ ] Export current data
- [ ] Manually edit a note in database
- [ ] In extension, select "Update existing" mode
- [ ] Click "Choose File" and select the export
- [ ] Verify:
  - Toast shows import statistics
  - Edited note was overwritten with exported value
  - Timestamps (created_at) were NOT changed
  - Mode dropdown updates helper text

### 4.4. Manual Testing - Error Handling

- [ ] Test invalid file format:
  - Create a `.txt` file with random content
  - Rename to `.json`
  - Try to import
  - Verify error toast with clear message
- [ ] Test network error:
  - Disconnect from backend (stop Rails server)
  - Try to export
  - Verify error toast with connection message
- [ ] Test backend API error:
  - Use invalid API key in settings
  - Try to export
  - Verify error toast with auth failure message

### 4.5. Manual Testing - Developer Mode Integration

- [ ] Verify Data Management section only visible when Developer Mode enabled
- [ ] Toggle Developer Mode off
- [ ] Verify Data Management section hidden
- [ ] Toggle Developer Mode on
- [ ] Verify section appears again
- [ ] Verify section positioned correctly (after Environment Config, before Save button)

### 4.6. Cross-Browser Testing

- [ ] Test in Chrome/Edge (Chromium)
- [ ] Test in Firefox (if Firefox support planned)
- [ ] Verify file downloads work in both browsers
- [ ] Verify file picker works in both browsers

---

## 5. Phase 5: Documentation

**Implements:** [requirements.md#9](./requirements.md#9-success-criteria)

**Justification:** Documentation helps users understand how to use the feature and serves as reference for future development.

### 5.1. Update Extension README

- [ ] Add section to `extension/README.md`:

```markdown
## Data Management (Developer Mode)

The extension provides data export and import capabilities accessible from the options page when Developer Mode is enabled.

### Accessing Data Management

1. Open extension options page (right-click extension icon → Options)
2. Enable "Developer Mode" toggle in top-right corner
3. Scroll to "Data Management" section

### Exporting Links

Click "Export All Links" to download a timestamped JSON file containing all your bookmarks.

**Export behavior:**
- Links tagged with `~temp~` are excluded (use for testing without polluting exports)
- Downloads to browser's default download location
- Filename format: `linkradar-export-YYYY-MM-DD-HHMMSS-<uuid>.json`

### Importing Links

**Select Import Mode:**
- **Skip duplicates** (default): Safe mode - existing links unchanged, only new links imported
- **Update existing**: Overwrites existing links with import data (timestamps preserved)

**Import Process:**
1. Select desired import mode from dropdown
2. Click "Choose File" and select LinkRadar export JSON file
3. Wait for import to complete
4. Review success message with statistics

**Import modes explained:**

*Skip duplicates mode:*
- Detects existing links by normalized URL
- Skips any link that already exists
- Preserves all existing data (notes, tags)
- Safe for adding new bookmarks without overwriting

*Update existing mode:*
- Overwrites existing links with imported data
- Updates notes and replaces all tags
- Preserves original `created_at` timestamp
- Useful for data migrations or fixing bulk errors

### Data Format

Export files use LinkRadar native JSON format (nested/denormalized). Tags matched by name on import (case-insensitive).

See backend documentation for detailed format specification.

### Troubleshooting

**Export fails:**
- Verify backend API is running and accessible
- Check API key is configured correctly in settings

**Import fails:**
- Verify file is LinkRadar export format (not external system)
- Check file is valid JSON
- Review error message in toast notification

**Developer Mode missing:**
- Developer Mode toggle is in top-right corner of options page header
- If missing, check extension version (feature requires v1.x+)
```

- [ ] Verify documentation is clear and accurate

---

## Implementation Complete

All phases implemented:
- ✅ Type definitions for export/import operations
- ✅ API client methods with error handling
- ✅ DataManagementSection component with export/import UI
- ✅ Integration into options page developer mode
- ✅ Manual testing of all user flows
- ✅ Documentation for users

**Complete feature:** Backend + Extension working together to provide frictionless data export/import for fearless dogfooding.

**Next steps:** Start using LinkRadar actively with confidence - your data is safe!

