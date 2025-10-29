import { createApp } from "vue"
import Options from "./Options.vue"
import "../styles/tailwind.css"

const app = createApp(Options)

// Global error handler to catch unhandled component errors
// This prevents the entire extension from crashing with a blank page
app.config.errorHandler = (err, instance, info) => {
  console.error("Vue component error:", err)
  console.error("Error occurred in component:", instance)
  console.error("Error info:", info)
  // Error is logged but app continues to function
}

// Development-only warnings handler for debugging
if (import.meta.env.DEV) {
  app.config.warnHandler = (msg, instance, trace) => {
    console.warn("Vue warning:", msg)
    console.warn("Component:", instance)
    console.warn("Trace:", trace)
  }
}

app.mount("#app")
