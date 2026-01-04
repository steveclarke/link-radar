# Modular Bin Scripts Architecture Guide

A comprehensive guide to the modular, class-based bin scripts setup used in this Rails project. Designed for copying to other projects.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Component Reference](#component-reference)
- [Copy Template](#copy-template)
- [Customization Guide](#customization-guide)
- [Usage Patterns](#usage-patterns)

---

## Overview

### What This Pattern Solves

Rails bin scripts (like `bin/setup`, `bin/dev`) need to run **before** Rails is loaded. This creates a challenge: how do you share code between scripts without Rails autoloading (Zeitwerk)?

This architecture solves that by:
1. Using `require_relative` for all loading (pre-Rails compatible)
2. Organizing shared code into a `lib/dev/tooling/` module
3. Keeping entry scripts lightweight (just delegate to classes)

### Key Principles

```
┌─────────────────────────────────────────────────────────────┐
│  bin/setup, bin/dev, bin/services                          │
│  (Thin entry points: delegate to orchestrator classes)     │
└────────────────────────┬────────────────────────────────────┘
                         │ require_relative
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  lib/dev/tooling.rb                                         │
│  (Loader: requires all tooling modules)                    │
└────────────────────────┬────────────────────────────────────┘
                         │ require_relative
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  lib/dev/tooling/                                           │
│  ├── env.rb              (ENV file operations)             │
│  ├── shell.rb            (Shell execution helpers)         │
│  ├── postgres.rb         (Postgres service checks)         │
│  ├── setup.rb            (Setup orchestration)             │
│  ├── dev_server.rb       (Dev server orchestration)        │
│  ├── services.rb         (Docker services orchestration)   │
│  ├── port_manager.rb     (Port conflict detection)         │
│  └── one_password_client.rb (Secrets management)           │
└─────────────────────────────────────────────────────────────┘
```

### Critical Rails Configuration

Add `dev` to the Zeitwerk ignore list in `config/application.rb`:

```ruby
# config/application.rb
config.autoload_lib(ignore: %w[assets tasks dev generators])
#                                        ^^^
```

This prevents Zeitwerk from trying to autoload files that use `require_relative`.

---

## Architecture

### Module Hierarchy

```ruby
Dev
└── Tooling                  # Namespace module (also loader)
    ├── Env                  # Module: ENV file operations
    ├── Shell                # Module: Shell command execution
    ├── Postgres             # Module: Postgres service checks
    ├── Setup                # Class: Full setup orchestration
    ├── DevServer            # Class: Dev server orchestration
    ├── Services             # Class: Docker services orchestration
    ├── PortManager          # Class: Port management
    └── OnePasswordClient    # Class: Secrets fetching
```

### Design Patterns

#### 1. Entry Point Pattern

Bin scripts are thin wrappers that delegate to orchestrator classes:

```ruby
#!/usr/bin/env ruby
require_relative "../lib/dev/tooling"

APP_ROOT = File.expand_path("..", __dir__)
Dev::Tooling::DevServer.new(APP_ROOT).run(ARGV) if __FILE__ == $0
```

#### 2. Orchestrator Class Pattern

Classes that orchestrate multi-step processes:
- Accept `app_root` in constructor
- Use `FileUtils.chdir(app_root)` to ensure correct working directory
- Delegate to utility modules for common operations
- Are idempotent (safe to run multiple times)

```ruby
class Setup
  attr_reader :app_root

  def initialize(app_root)
    @app_root = app_root
  end

  def run(reset: false)
    FileUtils.chdir(app_root) do
      install_dependencies
      create_env_file
      prepare_database(reset)
    end
  end
end
```

#### 3. Utility Module Pattern

Stateless modules with class methods grouped by concern:

```ruby
module Env
  def self.create(app_root)
    # Create .env from .env.sample
  end

  def self.load(app_root)
    # Load .env using dotenv
  end

  def self.update(app_root, values)
    # Update .env with key-value pairs
  end
end

module Shell
  def self.run!(*args)
    system(*args, exception: true)
  rescue
    puts "\n❌ Command failed: #{args.join(" ")}"
    raise
  end

  def self.run(*args)
    system(*args)
  end
end

module Postgres
  def self.running?
    system("docker compose ps -q postgres 2>/dev/null | grep -q .")
  end

  def self.warn_not_running
    puts "\n❌ PostgreSQL service is not running."
    puts "Please run 'bin/services' in another terminal first."
  end
end
```

#### 4. Final Command Execution

Use `exec` for the final command to:
- Replace the Ruby process with the target process
- Enable proper signal handling (Ctrl+C works correctly)

```ruby
def start_server(debug:, bind:, port:)
  $stdout.flush  # Flush output before exec
  exec "bin/rails", "server", "-b", bind, "-p", port
end
```

---

## Component Reference

### Entry Scripts

| File | Purpose | Delegates To |
|------|---------|--------------|
| `bin/setup` | Prepare development environment | `Setup` |
| `bin/dev` | Start Rails dev server | `DevServer` |
| `bin/services` | Manage Docker services | `Services` |
| `bin/configure-ports` | Interactive port configuration | `PortManager` |

### Utility Modules

| File | Purpose | Key Methods |
|------|---------|-------------|
| `lib/dev/tooling/env.rb` | ENV file management | `create`, `load`, `update`, `create_bruno` |
| `lib/dev/tooling/shell.rb` | Shell execution | `run!`, `run` |
| `lib/dev/tooling/postgres.rb` | Postgres checks | `running?`, `warn_not_running` |

### Orchestrator Classes

| File | Purpose | Key Methods |
|------|---------|-------------|
| `lib/dev/tooling/setup.rb` | Full setup orchestration | `run(reset:, check_postgres:)` |
| `lib/dev/tooling/dev_server.rb` | Dev server startup | `run(argv)` |
| `lib/dev/tooling/services.rb` | Docker services management | `run(argv)` |

### Service Wrappers

| File | Purpose | Key Methods |
|------|---------|-------------|
| `lib/dev/tooling/port_manager.rb` | Port conflict detection | `port_in_use?`, `check_for_port_conflicts`, `find_next_available_port` |
| `lib/dev/tooling/one_password_client.rb` | 1Password secrets | `fetch(item:, field:, vault:)`, `available?` |

### Method Reference

#### Env

```ruby
# Create .env from .env.sample if missing
Env.create(app_root)

# Create bruno/.env from bruno/.env.example
Env.create_bruno(app_root)

# Load .env using dotenv (bootstraps gem if needed)
Env.load(app_root)

# Update .env with key-value pairs
Env.update(app_root, { "PORT" => 3001, "DEBUG" => "true" })
```

#### Shell

```ruby
# Execute command, raise on failure
Shell.run!("bundle", "install")

# Execute command, return true/false
Shell.run("bin/rails", "db:seed")
```

#### Postgres

```ruby
# Check if postgres is running via docker compose
Postgres.running?  #=> true/false

# Display warning message
Postgres.warn_not_running
```

#### PortManager

```ruby
# Static method to check if port is in use
PortManager.port_in_use?(3000)  #=> true/false

# Instance usage
manager = PortManager.new(app_root, services: :backend_services)
manager.check_for_port_conflicts  # Exits if conflicts
manager.find_next_available_port(5432)  #=> 5433
manager.get_conflicts  #=> ["POSTGRES_PORT"]
manager.suggest_ports(["POSTGRES_PORT"])  #=> { "POSTGRES_PORT" => 5433 }
```

#### OnePasswordClient

```ruby
client = OnePasswordClient.new

if client.available?
  secret = client.fetch(
    item: "item-id-or-name",
    field: "password",
    vault: "MyVault"
  )
end
```

---

## Copy Template

### Step 1: Configure Rails (CRITICAL)

Add `dev` to Zeitwerk ignore list:

```ruby
# config/application.rb
config.autoload_lib(ignore: %w[assets tasks dev generators])
```

### Step 2: Create Directory Structure

```
lib/
└── dev/
    ├── tooling.rb
    └── tooling/
        ├── env.rb
        ├── shell.rb
        └── setup.rb
```

### Step 3: Create Loader Module

```ruby
# lib/dev/tooling.rb
# frozen_string_literal: true

# Loader for development tooling
#
# Uses require_relative (not Zeitwerk) because bin scripts run
# OUTSIDE the Rails environment before Rails is loaded.

# Utility modules
require_relative "tooling/env"
require_relative "tooling/shell"

# Orchestrators
require_relative "tooling/setup"
```

### Step 4: Create Env Module

```ruby
# lib/dev/tooling/env.rb
# frozen_string_literal: true

module Dev
  module Tooling
    module Env
      def self.create(app_root)
        require "fileutils"

        env_file = File.join(app_root, ".env")
        sample_file = File.join(app_root, ".env.sample")

        if !File.exist?(env_file) && File.exist?(sample_file)
          puts "Creating .env from .env.sample..."
          FileUtils.cp sample_file, env_file
        end
      end

      def self.load(app_root)
        begin
          require "dotenv"
        rescue LoadError
          require "bundler/inline"
          gemfile do
            source "https://rubygems.org"
            gem "dotenv"
          end
        end

        env_file = File.join(app_root, ".env")
        Dotenv.load(env_file) if File.exist?(env_file)
      end
    end
  end
end
```

### Step 5: Create Shell Module

```ruby
# lib/dev/tooling/shell.rb
# frozen_string_literal: true

module Dev
  module Tooling
    module Shell
      def self.run!(*args)
        system(*args, exception: true)
      rescue
        puts "\n❌ Command failed: #{args.join(" ")}"
        raise
      end

      def self.run(*args)
        system(*args)
      end
    end
  end
end
```

### Step 6: Create Setup Class

```ruby
# lib/dev/tooling/setup.rb
# frozen_string_literal: true

require_relative "env"
require_relative "shell"

module Dev
  module Tooling
    class Setup
      APP_NAME = "your-app-name"  # <-- CUSTOMIZE THIS

      attr_reader :app_root

      def initialize(app_root)
        @app_root = app_root
      end

      def run(reset: false)
        require "fileutils"

        FileUtils.chdir(app_root) do
          puts "== Setting up #{APP_NAME} =="

          install_dependencies
          create_env_file
          prepare_database(reset)

          puts "\n✅ Setup complete!"
        end
      end

      private

      def install_dependencies
        puts "\n== Installing dependencies =="
        system("bundle check") || Shell.run!("bundle install")
      end

      def create_env_file
        puts "\n== Copying sample files =="
        Env.create(app_root)
      end

      def prepare_database(reset = false)
        puts "\n== Preparing database =="
        if reset
          Shell.run! "bin/rails db:reset"
        else
          Shell.run! "bin/rails db:prepare"
        end
      end
    end
  end
end
```

### Step 7: Create bin/setup

```ruby
#!/usr/bin/env ruby
require "optparse"
require_relative "../lib/dev/tooling"

APP_ROOT = File.expand_path("..", __dir__)

options = { reset: false }

parser = OptionParser.new do |opts|
  opts.banner = "Usage: bin/setup [OPTIONS]"
  opts.separator ""
  opts.separator "Idempotent setup script for the development environment."
  opts.separator ""

  opts.on("--reset", "Reset the database before preparing") do
    options[:reset] = true
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit 0
  end
end

parser.parse!(ARGV)

Dev::Tooling::Setup.new(APP_ROOT).run(reset: options[:reset]) if __FILE__ == $0
```

Make executable: `chmod +x bin/setup`

### Step 8 (Optional): Add PortManager

Copy `lib/dev/tooling/port_manager.rb` if you need port conflict detection for Docker services. Customize the `SERVICES` hash:

```ruby
SERVICES = {
  "POSTGRES_PORT" => { port: 5432, name: "PostgreSQL", group: :backend_services },
  "REDIS_PORT" => { port: 6379, name: "Redis", group: :backend_services },
  # Add your services here
}.freeze
```

### Step 9 (Optional): Add OnePasswordClient

Copy `lib/dev/tooling/one_password_client.rb` if you use 1Password for secrets management. In `Setup`, customize:

```ruby
ONEPASSWORD_DEFAULTS = {
  item_id: "your-1password-item-id",
  vault: "YourVault",
  field: "credential"
}.freeze
```

---

## Customization Guide

### What to Customize for Each Project

| Component | What to Change |
|-----------|----------------|
| `Setup::APP_NAME` | Your application name |
| `Setup::ONEPASSWORD_DEFAULTS` | 1Password item/vault for master.key |
| `Setup::SYSTEM_PACKAGES` | OS packages your app needs (vips, ffmpeg, etc.) |
| `PortManager::SERVICES` | Docker services and their default ports |

### Adding New Setup Steps

Add a private method in `Setup` and call it from `run`:

```ruby
def run(reset: false)
  FileUtils.chdir(app_root) do
    # Existing steps...
    install_dependencies
    create_env_file
    prepare_database(reset)

    # Your new step
    seed_test_data
  end
end

private

def seed_test_data
  puts "\n== Seeding test data =="
  Shell.run! "bin/rails db:seed:test"
end
```

### Adding New Bin Scripts

Follow the entry point pattern:

```ruby
#!/usr/bin/env ruby
require_relative "../lib/dev/tooling"

APP_ROOT = File.expand_path("..", __dir__)
Dev::Tooling::YourClass.new(APP_ROOT).run(ARGV) if __FILE__ == $0
```

---

## Usage Patterns

### Running Multiple Environments (Git Worktrees)

When using git worktrees, each worktree needs unique ports. Use `bin/configure-ports`:

```bash
# In worktree 1
bin/configure-ports  # Uses default ports

# In worktree 2
bin/configure-ports  # Detects conflicts, suggests alternatives
```

### Skipping Setup for Fast Restarts

```bash
bin/dev --skip-setup  # Skip bundle install, db:prepare, etc.
bin/dev -s            # Short form
```

### Debug Mode

```bash
bin/dev --debug  # Start with rdbg debugger attached
bin/dev -d       # Short form
```

### Docker Services in Background

```bash
bin/services -d     # Detached mode (daemon)
bin/services down   # Stop services
bin/services logs   # View logs
```

---

## Files in This Implementation

```
backend/
├── bin/
│   ├── dev                  # Dev server entry point (5 lines)
│   ├── setup                # Setup entry point (45 lines)
│   ├── services             # Docker services entry point (5 lines)
│   └── configure-ports      # Interactive port config (171 lines)
├── lib/
│   └── dev/
│       ├── tooling.rb       # Loader (22 lines)
│       └── tooling/
│           ├── env.rb               # ENV operations (117 lines)
│           ├── shell.rb             # Shell execution (42 lines)
│           ├── postgres.rb          # Postgres checks (40 lines)
│           ├── setup.rb             # Setup orchestration (276 lines)
│           ├── dev_server.rb        # Dev server orchestration (133 lines)
│           ├── services.rb          # Docker services (147 lines)
│           ├── port_manager.rb      # Port management (261 lines)
│           └── one_password_client.rb # 1Password (94 lines)
└── config/
    └── application.rb       # Must ignore lib/dev in autoload_lib
```
