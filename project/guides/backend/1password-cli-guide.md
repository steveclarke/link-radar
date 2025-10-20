# 1Password CLI Quick Reference

**What:** LinkRadar uses 1Password CLI to fetch bootstrap secrets (like `master.key`) with biometric authentication. The `OnePasswordClient` class (in `lib/one_password_client.rb`) handles all interactions.

**Why:** Secure secret management without storing credentials in plaintext. Automatic fetch with biometric prompts.

## Setup (One-Time)

```bash
# Install
brew install 1password-cli

# Enable desktop integration
# 1Password app → Settings (⌘,) → Developer → Enable "Integrate with 1Password CLI"

# Verify
op whoami
```

That's it. No `op signin` needed—biometric prompts appear automatically.

## Where Things Live

```
backend/
├── lib/link_radar/
│   ├── support/
│   │   ├── one_password_client.rb  # OnePasswordClient class
│   │   ├── runner_support.rb       # RunnerSupport module
│   │   └── setup_runner.rb         # SetupRunner class
│   └── support.rb                  # Loader for all support utilities
└── bin/setup                       # Auto-fetches master.key on setup
```

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
| Fetch by ID | `client.fetch_by_id(item_id:, field:, vault:)` | Production code (stable) |
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

task :deploy do
  client = LinkRadar::Support::OnePasswordClient.new
  token = client.fetch_by_id(item_id: "xyz", field: "token", vault: "CI")
end
```

## Best Practices

- **Use item IDs, not names** - IDs won't break if items are renamed in 1Password
- **Check availability first** - `client.available?` before fetch attempts
- **Use Rails credentials for app secrets** - Only use `OnePasswordClient` for bootstrap/CI secrets
- **Let prompts happen** - The client uses `2>/dev/tty` to allow biometric prompts
- **Fail gracefully** - Methods return `nil` on failure, not exceptions

## When to Use vs Rails Credentials

**Use `OnePasswordClient`:**
- `master.key` (can't encrypt itself)
- CI/CD pipeline secrets
- Pre-Rails bootstrap secrets
- Developer-specific local credentials

**Use Rails Credentials:**
- API keys (Stripe, SendGrid, etc.)
- Service URLs and tokens
- Application configuration secrets
- Anything that can be encrypted with `master.key`

## Customizing master.key 1Password Configuration

The `bin/setup` script automatically fetches `master.key` from 1Password. The default LinkRadar project configuration is defined in `SetupRunner::ONEPASSWORD_DEFAULTS`, but you can override it using environment variables:

```bash
# In your .env file or shell profile
MASTER_KEY_OP_ITEM_ID="your-item-id-here"
MASTER_KEY_OP_VAULT="YourVaultName"
MASTER_KEY_OP_FIELD="credential"
```

**Default values:**
- Item ID: (LinkRadar project's master.key item)
- Vault: `LinkRadar`
- Field: `credential`

**When to customize:**
- Testing with different 1Password items
- Using a different vault organization
- Team members with different 1Password setups
- CI/CD pipelines with custom secret storage

## Working Without 1Password CLI

If you don't have 1Password CLI installed or prefer not to use it, you have several options:

**Option 1: Skip 1Password Integration**

Set `SKIP_ONEPASSWORD=true` in your `.env` file or shell:

```bash
# In .env or shell profile
SKIP_ONEPASSWORD=true
```

The setup script will skip 1Password and fall back to other methods.

**Option 2: Use RAILS_MASTER_KEY Environment Variable**

```bash
# In ~/.zshrc, ~/.bashrc, etc. (NOT in .env)
export RAILS_MASTER_KEY=your-master-key-here
```

**Option 3: Manual Entry**

If neither 1Password nor `RAILS_MASTER_KEY` is available, the setup script will prompt you to enter the master.key manually:

```
Enter your master.key: [input hidden]
```

**Option 4: Create master.key File Manually**

```bash
# Create the file with your key
echo "your-master-key-here" > backend/config/master.key

# Set secure permissions
chmod 600 backend/config/master.key
```

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
- Or set `SKIP_ONEPASSWORD=true` to skip 1Password integration

## Documentation

- **Official:** [1Password CLI Docs](https://developer.1password.com/docs/cli)
- **Related:** [Configuration Management Guide](configuration-management-guide.md)

