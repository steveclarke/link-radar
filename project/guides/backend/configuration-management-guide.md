# Configuration Management Guide

## Quick Overview

Link Radar uses:
- **[Anyway Config](https://github.com/palkan/anyway_config)** - Application settings with multiple sources
- **Rails Credentials** - Secrets and sensitive data

**Load Priority:** YAML → Credentials → ENV → Code (last wins)

## Where Configuration Lives

```
config/
├── configs/                      # Config classes
│   ├── application_config.rb    # Base class (singleton pattern)
│   └── core_config.rb           # Example config
├── core.yml                     # YAML config for CoreConfig
└── credentials.yml.enc          # Encrypted secrets
```

## Quick Start

**Create a config class:**
```bash
rails g anyway:config feature api_key timeout enabled
```

**Access anywhere:**
```ruby
CoreConfig.cors_origins
CoreConfig.frontend_url
```

**Override with ENV:**
```bash
CORE_CORS_ORIGINS="https://example.com"
CORE_FRONTEND_URL="https://app.example.com"
```

**Edit secrets:**
```bash
rails credentials:edit
rails credentials:edit --environment production
```

## Configuration Pattern

Config classes inherit from `ApplicationConfig` and use the singleton pattern:

```ruby
# Access via class methods
CoreConfig.cors_origins

# Or explicitly
CoreConfig.instance.cors_origins
```

See existing configs in `config/configs/` for examples.

## Cheat Sheet

| Task | Command/Pattern |
|------|-----------------|
| Generate config | `rails g anyway:config name attr1 attr2` |
| Access config | `MyConfig.attribute` |
| ENV override | `MYCONFIG_ATTRIBUTE=value` |
| Nested ENV | `MYCONFIG_NESTED__ATTRIBUTE=value` |
| Edit credentials | `rails credentials:edit` |
| YAML file location | `config/my_config.yml` |
| Config class location | `config/configs/my_config.rb` |

## Common Paths

- **Config classes:** `backend/config/configs/`
- **YAML files:** `backend/config/*.yml`
- **Credentials:** `backend/config/credentials/` or `backend/config/credentials.yml.enc`
- **Base class:** `backend/config/configs/application_config.rb`

## Best Practices

1. **Defaults** → In code (`attr_config`)
2. **Environment-specific** → YAML files
3. **Secrets** → Rails credentials
4. **Production overrides** → Environment variables
5. **Validation** → Use `required` for critical values

## Documentation

- [Anyway Config Docs](https://github.com/palkan/anyway_config) - Full feature reference
- [Rails Credentials](https://guides.rubyonrails.org/security.html#custom-credentials) - Managing secrets

For detailed usage (type coercion, validation, testing, loaders, etc.), refer to the Anyway Config documentation.
