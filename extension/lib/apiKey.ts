import { STORAGE_KEYS } from "./config"

/**
 * Read the API key from browser sync storage.
 * Returns undefined when not configured.
 */
export async function getApiKey(): Promise<string | undefined> {
  const result = await browser.storage.sync.get(STORAGE_KEYS.API_KEY)
  return result[STORAGE_KEYS.API_KEY]
}

/**
 * Persist the API key to browser sync storage.
 */
export async function setApiKey(apiKey: string): Promise<void> {
  await browser.storage.sync.set({ [STORAGE_KEYS.API_KEY]: apiKey })
}
