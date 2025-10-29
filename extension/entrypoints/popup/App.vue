<script lang="ts" setup>
/**
 * Main popup application component.
 * Handles app initialization and layout.
 */
import { onMounted } from "vue"
import NotificationToast from "../../lib/components/NotificationToast.vue"
import ApiKeyWarning from "./components/ApiKeyWarning.vue"
import AppHeader from "./components/AppHeader.vue"
import LinkForm from "./components/LinkForm.vue"
import TabInfoDisplay from "./components/TabInfoDisplay.vue"
import { useAppInit } from "./composables/useAppInit"

const {
  isAppLoading,
  isAppReady,
  currentTabInfo,
  initApp,
} = useAppInit()

onMounted(initApp)
</script>

<template>
  <div class="flex flex-col gap-4 p-4 box-border">
    <!-- Loading state -->
    <div v-if="isAppLoading" class="text-center py-8">
      <p class="text-slate-600">
        Loading...
      </p>
    </div>

    <!-- Content only shows after loading -->
    <template v-else>
      <AppHeader />
      <ApiKeyWarning />
      <TabInfoDisplay :tab-info="currentTabInfo" />
      <LinkForm
        :current-tab-info="currentTabInfo"
        :is-app-ready="isAppReady"
      />
    </template>

    <NotificationToast />
  </div>
</template>

<style>
html,
body {
  width: 400px;
  min-height: 300px;
  margin: 0;
  box-sizing: border-box;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  background: #f8fafc;
}
</style>
