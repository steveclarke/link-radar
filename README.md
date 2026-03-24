# LinkRadar

**A personal knowledge radar that captures interesting content effortlessly and surfaces emerging trends in your learning and interests over time.**

## Project Structure

LinkRadar is a monorepo:

- **`backend/`** — Rails 8.1 API (Ruby 3.4.x, PostgreSQL 18)
- **`extension/`** — Chrome extension (Vue 3, WXT, TypeScript, Tailwind CSS 4)
- **`project/`** — Developer guides
- **`deploy/`** — Kamal deployment config

## Getting Started

See component-specific READMEs for setup:

- **Backend**: [backend/README.md](backend/README.md)
- **Extension**: [extension/README.md](extension/README.md)

### Development Setup

Run the initialization script to set up your development environment:

```bash
bin/dev-init
```

This creates your personal workspace file with all formatter/linter settings pre-configured.

**Using VSCode/Cursor (Recommended)**

After running `bin/dev-init`, open the workspace:

```bash
code link-radar.code-workspace  # or 'cursor' if using Cursor
```

Install recommended extensions when prompted. Formatting and linting work automatically.

Two workflows are supported:

1. **Workspace workflow** (recommended): Open `link-radar.code-workspace` for all folders
2. **Single-folder workflow**: Open `backend/` directly for focused backend development

Both get identical formatter/linter settings. See the [VSCode Guide](project/guides/vscode-guide.md) for details.

## Contributing

This project is in active development and open to contributors.

If you're interested, open an issue and make your suggestion — whether it's feature ideas, technical approaches, improvements, or if you want to guinea pig it. Your input is welcome.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
