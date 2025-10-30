<script lang="ts" setup>
/**
 * Options page orchestrator component for the Link Radar browser extension.
 * Pure layout component with no business logic.
 *
 * @component
 */
import NotificationToast from "../../lib/components/NotificationToast.vue"
import SettingsForm from "./components/SettingsForm.vue"
import SettingsHeader from "./components/SettingsHeader.vue"
</script>

<template>
  <div class="max-w-5xl mx-auto p-6 font-sans">
    <SettingsHeader />
    <SettingsForm />
    <NotificationToast />
  </div>
</template>
