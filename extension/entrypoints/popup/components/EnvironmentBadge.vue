<script lang="ts" setup>
import type { BackendEnvironment } from "../../../lib/settings"
import { computed, onMounted, ref } from "vue"
import { getActiveBackendUrl, getBackendEnvironment } from "../../../lib/settings"

// Props
interface Props {
  showProduction?: boolean
}

const { showProduction = false } = defineProps<Props>()

// State
const backendEnvironment = ref<BackendEnvironment>("production")
const activeBackendUrl = ref("")

// Computed environment badge properties
const environmentBadge = computed(() => {
  switch (backendEnvironment.value) {
    case "local":
      return {
        icon: "🟡",
        label: "Local Dev",
        bgColor: "bg-yellow-100",
        textColor: "text-yellow-800",
        borderColor: "border-yellow-300",
      }
    case "custom":
      return {
        icon: "🔵",
        label: "Custom",
        bgColor: "bg-blue-100",
        textColor: "text-blue-800",
        borderColor: "border-blue-300",
      }
    case "production":
    default:
      return {
        icon: "🟢",
        label: "Production",
        bgColor: "bg-green-100",
        textColor: "text-green-800",
        borderColor: "border-green-300",
      }
  }
})

// Load environment on mount
onMounted(async () => {
  backendEnvironment.value = await getBackendEnvironment()
  activeBackendUrl.value = await getActiveBackendUrl()
})
</script>

<template>
  <div
    v-if="showProduction || backendEnvironment !== 'production'"
    class="px-2 py-0.5 rounded-full text-xs font-medium border"
    :class="[
      environmentBadge.bgColor,
      environmentBadge.textColor,
      environmentBadge.borderColor,
    ]"
    :title="`Backend: ${activeBackendUrl}`"
  >
    {{ environmentBadge.icon }} {{ environmentBadge.label }}
  </div>
</template>
