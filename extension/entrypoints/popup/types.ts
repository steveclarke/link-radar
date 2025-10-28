export interface TabInfo {
  title: string
  url: string
  favicon?: string
}

export interface MessageState {
  text: string
  type: "success" | "error"
}

export interface LinkState {
  isLinked: boolean
  linkId: string | null
  isChecking: boolean
}

export interface LinkData {
  title: string
  url: string
  note: string
  tags: string[]
  saved_at: string
}
