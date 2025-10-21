# 1Password CLI Quick Reference

**What:** LinkRadar uses 1Password CLI to fetch secrets needed to set up the
*application locally (like `master.key`) with biometric authentication. This is
***only for developer workstations**—the `op` CLI integrates with your local
*1Password desktop app. The `OnePasswordClient` class (in
*`lib/one_password_client.rb`) handles all interactions.

**Why:** Secure secret management for local development without storing
*credentials in plaintext. Automatic fetch with biometric prompts when setting
*up the app on your machine. Production and CI environments use different secret
*management approaches.

## Setup (One-Time)

```bash
# Install
brew install 1password-cli

# Enable desktop integration
# 1Password app → Settings (⌘,) → Developer → Enable "Integrate with 1Password CLI"

# Verify (will trigger biometric sign-in on first use)
op whoami
```

**Note:** On first use, you'll need to sign in with biometric authentication. Run `op signin` or any `op` command to trigger the biometric prompt.

## Quick Start

```ruby
require_relative 'lib/link_radar/support'

client = LinkRadar::Support::OnePasswordClient.new

# Fetch by item ID (recommended—stable if renamed)
secret = client.fetch_by_id(
  item_id: "abc123xyz",
  field: "credential",
  vault: "LinkRadar"
)

# Or fetch by name
secret = client.fetch(
  item: "My Secret",
  field: "password",
  vault: "MyVault"
)
```

## Cheat Sheet

| Task | Method | When to Use |
|------|--------|-------------|
| Fetch by ID | `client.fetch_by_id(item_id:, field:, vault:)` | Dev scripts (stable if item renamed) |
| Fetch by name | `client.fetch(item:, field:, vault:)` | Quick scripts, exploration |
| Check availability | `client.available?` | Before attempting fetch |
| Get CLI path | `client.cli_path` | Debugging |

## Common Use Cases

**In bin scripts:**
```ruby
require_relative '../lib/link_radar/support'

client = LinkRadar::Support::RunnerSupport.onepassword_client
key = client.fetch_by_id(...) if client.available?
```

**In rake tasks:**
```ruby
require_relative 'lib/link_radar/support'

task :setup_local_env do
  client = LinkRadar::Support::OnePasswordClient.new
  api_key = client.fetch_by_id(item_id: "xyz", field: "credential", vault: "LinkRadar")
end
```

## Best Practices

- **Use item IDs, not names** - IDs won't break if items are renamed in 1Password
- **Check availability first** - `client.available?` before fetch attempts
- **Local development only** - Only use `OnePasswordClient` for setting up the app on developer workstations
- **Let prompts happen** - The client uses `2>/dev/tty` to allow biometric prompts
- **Fail gracefully** - Methods return `nil` on failure, not exceptions

## When to Use vs Rails Credentials

**Use `OnePasswordClient` (local development only):**
- `master.key` (needed to decrypt Rails credentials, can't encrypt itself)
- Secrets needed during initial application setup on your machine
- Developer-specific local credentials

**Use Rails Credentials:**
- API keys (Stripe, SendGrid, etc.)
- Service URLs and tokens
- Application configuration secrets
- Anything that can be encrypted with `master.key`
- **All production and CI secrets**

## How LinkRadar Uses 1Password CLI

LinkRadar uses the 1Password CLI in several places to fetch secrets during local development setup. These are secrets that can't be stored in git and need to be fetched securely on each developer's machine.

### Fetching master.key During Setup

The primary use case is fetching the Rails `master.key` during the `bin/setup` process. The `master.key` is needed to decrypt Rails credentials but can't encrypt itself, making it perfect for 1Password CLI integration.

**How it works:**
- When you run `bin/setup`, it automatically attempts to fetch `master.key` from 1Password
- Uses biometric authentication via the desktop app
- Creates `config/master.key` with the correct permissions

**Default configuration:**
- **Vault:** `LinkRadar`
- **Item ID:** (LinkRadar project's master.key item)
- **Field:** `credential`

**Customizing the configuration:**

If you need to use different 1Password items or vaults, you can override the defaults using environment variables:

```bash
# In your .env file or shell profile
MASTER_KEY_OP_ITEM_ID="your-item-id-here"
MASTER_KEY_OP_VAULT="YourVaultName"
MASTER_KEY_OP_FIELD="credential"
```

**When to customize:**
- Testing with different 1Password items
- Using a different vault organization
- Team members with different 1Password setups

## Troubleshooting

**"account is not signed in"**
- Run any `op` command—you'll get a biometric prompt
- Or manually: `op signin`

**No biometric prompt appears**
- Check desktop integration: 1Password app → Settings → Developer
- Restart 1Password app after enabling

**CLI not found**
- Install: `brew install 1password-cli`
- Verify: `which op`

## Documentation

- **Official:** [1Password CLI Docs](https://developer.1password.com/docs/cli)
- **Related:** [1Password Service Accounts Guide](1password-service-accounts-guide.md) (for production/staging/CI)
- **Related:** [Configuration Management Guide](configuration-management-guide.md)

