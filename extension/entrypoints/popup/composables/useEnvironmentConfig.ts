import type { BackendEnvironment } from "../../../lib/settings"

/**
 * Configuration object for environment badge styling and display
 */
export interface EnvironmentConfig {
  /** Icon name from Material Symbols */
  icon: string
  /** Hex color for the icon */
  iconColor: string
  /** Display label for the environment */
  label: string
  /** Tailwind background color class */
  bgColor: string
  /** Tailwind text color class */
  textColor: string
  /** Tailwind border color class */
  borderColor: string
}

/**
 * Returns environment configuration based on the backend environment type.
 * Provides consistent styling across EnvironmentBadge and Options components.
 *
 * @param environment - The backend environment type
 * @returns Configuration object with icon, colors, and labels
 */
export function getEnvironmentConfig(environment: BackendEnvironment): EnvironmentConfig {
  switch (environment) {
    case "local":
      return {
        icon: "material-symbols:circle",
        iconColor: "#eab308", // yellow-500
        label: "Local Dev",
        bgColor: "bg-yellow-100",
        textColor: "text-yellow-800",
        borderColor: "border-yellow-300",
      }
    case "custom":
      return {
        icon: "material-symbols:circle",
        iconColor: "#3b82f6", // blue-500
        label: "Custom",
        bgColor: "bg-blue-100",
        textColor: "text-blue-800",
        borderColor: "border-blue-300",
      }
    case "production":
    default:
      return {
        icon: "material-symbols:circle",
        iconColor: "#22c55e", // green-500
        label: "Production",
        bgColor: "bg-green-100",
        textColor: "text-green-800",
        borderColor: "border-green-300",
      }
  }
}
