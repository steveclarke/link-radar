# VSCode Settings Guide

## Table of Contents

- [VSCode Settings Guide](#vscode-settings-guide)
  - [Table of Contents](#table-of-contents)
  - [About This Guide](#about-this-guide)
  - [Setup for This Project](#setup-for-this-project)
    - [For Workspace Workflow (Recommended)](#for-workspace-workflow-recommended)
    - [For Single-Folder Workflow](#for-single-folder-workflow)
  - [Why Use a Workspace? (TL;DR: Monorepo Power + AI Context)](#why-use-a-workspace-tldr-monorepo-power--ai-context)
    - [The Question](#the-question)
    - [The Answer: Per-Folder Tooling + Full AI Context](#the-answer-per-folder-tooling--full-ai-context)
    - [When to Open Directly vs Workspace](#when-to-open-directly-vs-workspace)
  - [Extension Roles](#extension-roles)
    - [Ruby LSP (`shopify.ruby-lsp`)](#ruby-lsp-shopifyruby-lsp)
    - [Standard Ruby (`testdouble.vscode-standard-ruby`)](#standard-ruby-testdoublevscode-standard-ruby)
    - [Debug (`koichisasada.vscode-rdbg`)](#debug-koichisasadavscode-rdbg)
    - [Prettier (`esbenp.prettier-vscode`)](#prettier-esbenpprettier-vscode)
    - [YAML (`redhat.vscode-yaml`)](#yaml-redhatvscode-yaml)
  - [Customization](#customization)
    - [Adding Your Own Folders](#adding-your-own-folders)
    - [Changing Formatter Settings](#changing-formatter-settings)
    - [Disabling Format on Save](#disabling-format-on-save)
  - [Troubleshooting](#troubleshooting)
    - [Settings are grayed out in backend/.vscode/settings.json](#settings-are-grayed-out-in-backendvscodesettingsjson)
    - [Formatting not working](#formatting-not-working)
    - [Linting errors not showing](#linting-errors-not-showing)
    - [Different settings than other developers](#different-settings-than-other-developers)
  - [Formatting Flow](#formatting-flow)
  - [Tasks vs Launch Configurations](#tasks-vs-launch-configurations)
    - [Key Difference](#key-difference)
    - [Typical Pattern](#typical-pattern)
  - [How VSCode Settings Work](#how-vscode-settings-work)
    - [Settings Precedence (highest priority wins)](#settings-precedence-highest-priority-wins)
    - [The Gray Text](#the-gray-text)
  - [Why Duplication?](#why-duplication)
  - [Appendix A: Complete Settings Inventory](#appendix-a-complete-settings-inventory)
    - [`[ruby]` Settings](#ruby-settings)
    - [`[Gemfile]` Settings](#gemfile-settings)
    - [`[json]` Settings](#json-settings)
    - [`[yaml]` Settings](#yaml-settings)
    - [`rubyLsp.formatter`](#rubylspformatter)
    - [`rubyLsp.linters`](#rubylsplinters)
    - [`rubyLsp.enabledFeatures`](#rubylspenabledfeatures)

## About This Guide

This guide covers VSCode settings for the LinkRadar monorepo. **VSCode** and **Cursor** (a VSCode fork with AI superpowers) both use the same configuration system, so everything here applies to both editors.

We use Cursor for our team because it provides enterprise AI tooling and agentic coding assistance, plus all the VSCode features you know and love.

## Setup for This Project

### For Workspace Workflow (Recommended)

1. Run the init script:
   ```bash
   bin/dev-init
   ```

2. Open the workspace:
   ```bash
   code link-radar.code-workspace  # or 'cursor' for Cursor
   ```

3. Install recommended extensions when prompted

4. Done! Formatting works automatically.

### For Single-Folder Workflow

1. Open backend directly:
   ```bash
   code backend/  # or 'cursor backend/'
   ```

2. Install recommended extensions when prompted

3. Settings in `backend/.vscode/settings.json` work automatically

**Want to understand why we use workspaces?** See the next section.

## Why Use a Workspace? (TL;DR: Monorepo Power + AI Context)

### The Question

Why can't we just do `cursor .` or `code .` at the monorepo root? Why do we need a workspace file?

### The Answer: Per-Folder Tooling + Full AI Context

**1. Different folders need different tooling**

Our monorepo has multiple projects, each with its own tech stack:

- **`backend/`** - Ruby on Rails → needs Ruby LSP, Standard Ruby formatter, RSpec runner
- **`frontend/`** (coming) - Nuxt/Vue → needs Volar, ESLint, Vue tooling  
- **`cli/`** (coming) - Ruby CLI tools → different settings than backend
- **`project/`** - Documentation, specs, guides

If you open the monorepo root directly (`cursor .`), VSCode treats it as ONE project. You can't apply Ruby formatting to `backend/` files while applying Vue tooling to `frontend/` files. Everything gets the same settings.

**Workspaces solve this** by letting you "mount" each top-level directory as a separate workspace root. VSCode then applies folder-specific settings from each folder's `.vscode/settings.json` file.

According to [VSCode's workspace documentation](https://code.visualstudio.com/docs/editing/workspaces/workspaces), multi-root workspaces allow you to:

> Configure settings that only apply to a specific folder or folders but not others... Persist task and debugger launch configurations that are only valid in the context of that workspace... Selectively enable or disable extensions only for that workspace.

**2. AI agents get access to your entire codebase**

This is the killer feature in the age of AI coding assistants.

When you open via workspace, your AI agent (Cursor, GitHub Copilot, etc.) has the **entire monorepo** in context:

- **Frontend dev asking about API shape?** Tag a backend controller file in your agent chat.
- **Backend dev needs to understand frontend state?** Access Vue components directly.
- **Anyone need specs/docs?** All guides, requirements, and architecture docs in `project/` are right there.

**Without workspace:** If you open `backend/` directly, you can't easily access frontend code, project docs, or other parts of the monorepo. You'd have to manually open files from disk or switch between multiple VSCode windows.

**With workspace:** Everything is one click away. Drag a file from any folder into your AI chat. Your agent sees the full picture.

**3. The "root" folder trick**

You'll see our workspace file has three folders:

```json
{
  "folders": [
    { "name": "backend", "path": "backend" },
    { "name": "project", "path": "project" },
    { "name": "root", "path": "." }  // ← This!
  ]
}
```

**Why "root"?** It gives you access to monorepo-level files:

- `bin/dev-init` and other scripts
- `.editorconfig`, `.gitignore`
- Root-level documentation like `README.md`

**But wait, doesn't this duplicate everything?** Yes! If you mount `root` (`.`), you'd see `root/backend/`, `root/project/`, etc. alongside the dedicated `backend` and `project` workspace roots. Confusing!

**That's why we exclude them in workspace settings:**

```json
"files.exclude": {
  "backend": true,  // Hide root/backend/ since we have dedicated backend root
  "project": true   // Hide root/project/ since we have dedicated project root
}
```

Now the `root` folder in your File Explorer only shows monorepo-level files, not duplicates of your workspace roots.

### When to Open Directly vs Workspace

**Use workspace (recommended):**
- You're working across multiple parts of the codebase
- You want AI agent access to everything
- You need to reference docs, specs, or other folder contents frequently
- You're doing full-stack work (backend + frontend)

**Open folder directly (`cursor backend/`):**
- Focused, heads-down work on just backend
- You don't need AI context from other folders
- Faster startup (VSCode loads less)
- Simpler File Explorer (just backend files)

Both workflows work! That's why we duplicate settings (explained later in "Why Duplication?").

## Extension Roles

### Ruby LSP (`shopify.ruby-lsp`)

- **Purpose:** IDE features for Ruby development
- **Provides:**
  - Autocomplete
  - Go to definition
  - Hover documentation
  - Find references
  - Workspace symbols
  - Inline diagnostics/linting
- **Does NOT:** Format code (we use Standard Ruby extension for that)

### Standard Ruby (`testdouble.vscode-standard-ruby`)

- **Purpose:** Code formatting
- **Provides:** Automatic formatting on save using Standard Ruby style guide
- **When it runs:** Every time you save a Ruby file or run "Format Document"

### Debug (`koichisasada.vscode-rdbg`)

- **Purpose:** Ruby debugging
- **Provides:** Breakpoints, step-through debugging, variable inspection

### Prettier (`esbenp.prettier-vscode`)

- **Purpose:** Format JSON, JavaScript, CSS, etc.
- **Used for:** JSON files in this project

### YAML (`redhat.vscode-yaml`)

- **Purpose:** Format and validate YAML files
- **Used for:** Config files, GitHub Actions

## Customization

### Adding Your Own Folders

Edit your personal `link-radar.code-workspace`:

```json
{
  "folders": [
    { "name": "backend", "path": "backend" },
    { "name": "project", "path": "project" },
    { "name": "my-notes", "path": "../my-notes" }  // Your additions
  ]
}
```

Your workspace file is gitignored, so your customizations won't affect other developers.

### Changing Formatter Settings

**If using workspace:** Edit `link-radar.code-workspace`  
**If opening backend directly:** Edit `backend/.vscode/settings.json`

See inline comments in those files for guidance on each setting.

### Disabling Format on Save

If you prefer manual formatting:

```json
"[ruby]": {
  "editor.formatOnSave": false,  // Change to false
  "editor.defaultFormatter": "testdouble.vscode-standard-ruby"
}
```

You can still format manually with Shift+Option+F (Mac) or Shift+Alt+F (Windows/Linux).

## Troubleshooting

### Settings are grayed out in backend/.vscode/settings.json

**Cause:** You opened via workspace file  
**Solution:** This is normal! Settings are duplicated in your workspace file and working from there. The gray text is just VSCode saying "I'm reading these from workspace instead."

### Formatting not working

1. **Check Standard Ruby extension is installed:**
   - Open Extensions panel (Cmd+Shift+X)
   - Search for "Standard Ruby"
   - Install `testdouble.vscode-standard-ruby`

2. **Reload window:**
   - Cmd+Shift+P → "Developer: Reload Window"

3. **Check which file is open:**
   - Workspace users: Formatting set in workspace file
   - Direct folder users: Formatting set in `backend/.vscode/settings.json`

4. **Verify formatOnSave is enabled:**
   - Check the `[ruby]` section in your settings
   - Should be `"editor.formatOnSave": true`

### Linting errors not showing

1. **Check Ruby LSP is running:**
   - Look for "Ruby LSP" in status bar (bottom)
   - Should show version number and "Running"

2. **Check diagnostics are enabled:**
   - Verify `"rubyLsp.enabledFeatures.diagnostics": true`

3. **Restart Ruby LSP:**
   - Cmd+Shift+P → "Ruby LSP: Restart Server"

### Different settings than other developers

**Cause:** Your personal workspace file has different settings  
**Solution:** Compare your `link-radar.code-workspace` with `link-radar.code-workspace.template` to see what's different. You can copy the template to reset to defaults.

## Formatting Flow

**What happens when you save a Ruby file:**

1. VSCode detects file saved
2. Checks `editor.formatOnSave` for `[ruby]` → `true`
3. Looks for `editor.defaultFormatter` for `[ruby]` → `"testdouble.vscode-standard-ruby"`
4. Calls Standard Ruby extension
5. Standard Ruby extension runs `bin/standardrb --fix` on the file
6. File is formatted and saved with corrections

**Separately, Ruby LSP provides:**

- Linting diagnostics via `rubyLsp.linters: ["standard"]`
- IDE features (hover, completion, go-to-def, etc.)
- Does NOT format (that's the Standard Ruby extension's job)

## Tasks vs Launch Configurations

### Key Difference

- **Tasks (`tasks.json`):** Run things without debugging (start servers, build, lint, run tests)
- **Launch (`launch.json`):** Debug things (attach debugger, set breakpoints, inspect variables)

### Typical Pattern

1. **Task** starts your Rails server with debug mode enabled
2. **Launch** attaches the debugger to that running server

Example workflow:
```
Terminal > Run Task > "Rails Server w/Docker Services"
    ↓
Run & Debug > "Attach with rdbg"
```

Tasks handle the "run" part, launch handles the "debug" part.

## How VSCode Settings Work

### Settings Precedence (highest priority wins)

1. **Workspace settings** (when opened via `.code-workspace` file)
2. **Workspace folder settings** (when opened via direct folder, or `.vscode/settings.json`)
3. **User settings** (global to your VSCode/Cursor installation)

**Key point:** When you open via workspace file (`cursor link-radar.code-workspace`), the workspace file settings completely replace folder settings. That's why you see them grayed out - VSCode is telling you "I'm ignoring these because you opened via workspace file."

### The Gray Text

If you see settings grayed out in `backend/.vscode/settings.json` with the message "This setting cannot be applied in this workspace," **this is normal!** It means you opened via workspace file and those settings are being read from the workspace instead.

The grayed text is just VSCode telling you "I'm not using these right now because workspace settings take precedence." The settings still work - they're just coming from your workspace file.

## Why Duplication?

**The Problem:** VSCode/Cursor has two ways to open a project, and they handle settings differently:

1. **Opening a folder directly:**
   ```bash
   cursor backend/   # or: code backend/
   ```
   ✅ Uses settings from `backend/.vscode/settings.json`

2. **Opening via workspace file** (what VSCode calls a "multi-root workspace"):
   ```bash
   cursor link-radar.code-workspace   # or: code link-radar.code-workspace
   ```
   ❌ Ignores `backend/.vscode/settings.json` completely
   
   ✅ Uses settings from the workspace file instead

When you open via workspace file, you'll see settings in `backend/.vscode/settings.json` grayed out with the message "This setting cannot be applied in this workspace. It will be applied when you open the containing workspace folder directly."

**The Solution:** Duplicate **language-specific formatter/linter settings** in both places so formatting works correctly whether you:
- Open `backend/` folder directly (focused work on just backend)
- Open `link-radar.code-workspace` (see all folders: backend, project, docs)

Window-level settings (like `files.exclude`, `editor.rulers`) only live in the workspace file since they're workspace-specific.

**The Benefit:** No manual configuration. Every developer gets identical formatter/linter behavior regardless of their preferred workflow.

---

## Appendix A: Complete Settings Inventory

This appendix provides detailed documentation for every setting in our VSCode/Cursor configuration.

### `[ruby]` Settings

```json
"[ruby]": {
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "testdouble.vscode-standard-ruby"
}
```

- **Purpose:** Configure Ruby file formatting
- **`formatOnSave`:** Automatically format Ruby files when you save
- **`defaultFormatter`:** Use Standard Ruby extension (not Ruby LSP) for formatting
- **Why Standard Ruby extension?** Works reliably in both VSCode and Cursor. Ruby LSP formatting has quirks in Cursor.

> **Note:** If you know how to make Ruby LSP formatting work reliably without requiring the Standard Ruby extension, please contact Steve at steve@sevenview.ca. We'd love to simplify the tooling setup!

### `[Gemfile]` Settings

```json
"[Gemfile]": {
  "editor.formatOnSave": true
}
```

- **Purpose:** Format Gemfiles on save
- Uses same formatter as Ruby files (Standard Ruby extension)

### `[json]` Settings

```json
"[json]": {
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.formatOnSave": true
}
```

- **Purpose:** Format JSON files consistently
- **Formatter:** Prettier (industry standard for JSON/JS/CSS)
- **When it runs:** Automatically on save

### `[yaml]` Settings

```json
"[yaml]": {
  "editor.defaultFormatter": "redhat.vscode-yaml",
  "editor.formatOnSave": true
}
```

- **Purpose:** Format YAML config files (database.yml, GitHub Actions, etc.)
- **Formatter:** RedHat's YAML extension (most reliable for YAML)
- **When it runs:** Automatically on save

### `rubyLsp.formatter`

```json
"rubyLsp.formatter": "standard"
```

- **Purpose:** Tell Ruby LSP which formatter to use for diagnostics
- **Value:** `"standard"` - use Standard Ruby linter
- **Note:** This is for *diagnostics*, not actual formatting. Formatting is handled by `editor.defaultFormatter` (the Standard Ruby extension).

### `rubyLsp.linters`

```json
"rubyLsp.linters": ["standard"]
```

- **Purpose:** Configure which linters Ruby LSP should run
- **Value:** `["standard"]` - use Standard Ruby for linting
- **What it does:** Shows inline errors/warnings as you type

### `rubyLsp.enabledFeatures`

```json
"rubyLsp.enabledFeatures": {
  "codeActions": true,
  "diagnostics": true,
  "documentHighlights": true,
  "documentLink": true,
  "documentSymbols": true,
  "foldingRanges": true,
  "formatting": true,
  "hover": true,
  "inlayHint": true,
  "onTypeFormatting": true,
  "selectionRanges": true,
  "semanticHighlighting": true,
  "completion": true,
  "codeLens": true,
  "definition": true,
  "workspaceSymbol": true,
  "signatureHelp": true
}
```

Explicitly enable all Ruby LSP IDE features:

- **`codeActions`:** Quick fixes, refactorings (e.g., "Extract method")
- **`diagnostics`:** Show linting errors inline as you type
- **`documentHighlights`:** Highlight all occurrences of symbol under cursor
- **`documentLink`:** Make source comments clickable (`# source://path`)
- **`documentSymbols`:** File outline, breadcrumbs navigation
- **`foldingRanges`:** Code folding regions
- **`formatting`:** Format document command (actual formatting done by Standard Ruby extension)
- **`hover`:** Show documentation when hovering over code
- **`inlayHint`:** Inline type hints
- **`onTypeFormatting`:** Format as you type
- **`selectionRanges`:** Smart selection expansion (Cmd+Shift+→)
- **`semanticHighlighting`:** Better syntax coloring based on code understanding
- **`completion`:** Autocomplete suggestions
- **`codeLens`:** Inline actionable buttons (e.g., "Run test")
- **`definition`:** Go to definition (F12)
- **`workspaceSymbol`:** Project-wide symbol search (Cmd+T)
- **`signatureHelp`:** Method parameter hints as you type

