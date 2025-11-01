# Ruby 3.4 + Zeitwerk + Eager Loading Issue - SUMMARY

**Date:** November 1, 2025  
**Status:** ✅ RESOLVED

## Resolution

### Root Cause Identified
Developer tooling code in `lib/link_radar/tooling/` and `lib/link_radar/sample_data/` was being **eager-loaded in production**, triggering a Ruby 3.4 + Zeitwerk + `bundled_gems.rb` conflict.

### The Fix
Reorganized lib/ directory structure:
```
lib/
├── dev/                   # Ignored from autoload
│   ├── tooling/
│   └── sample_data/
└── link_radar/           # Ready for runtime code
    └── .keep
```

Updated configuration:
```ruby
config.autoload_lib(ignore: %w[assets tasks dev])
```

### Result
✅ Production boots successfully with default settings (eager_load=true, Bootsnap enabled)

---

## Investigation Summary

### ✅ Fresh Rails 8.1 App Works Fine
Created brand new Rails 8.1 API-only app with:
- Ruby 3.4.7
- ActionView loaded
- JBuilder enabled  
- Eager loading enabled
- Bootsnap enabled
- HttpAuthentication::Token included

**Result:** BOOTS SUCCESSFULLY in production mode

### ❌ Existing App Failed
Same configuration but failed with:
```
LoadError: cannot load such file -- rack/session/abstract/id
```

**Reason:** Had custom lib/ code being autoloaded

## What We've Eliminated

1. ✅ **NOT a Bootsnap issue** - removing Bootsnap doesn't fix it
2. ✅ **NOT a cache issue** - clearing tmp/cache doesn't fix it  
3. ✅ **NOT a gem version issue** - both apps use identical versions
4. ✅ **NOT specific to HttpAuthentication** - happens even without it
5. ✅ **NOT JBuilder specific** - fresh app with JBuilder works

## Stack Trace Analysis

The require chain that fails:
```
bundled_gems.rb (Ruby 3.4) 
  ↓
zeitwerk/core_ext/kernel.rb (Zeitwerk)
  ↓
actionpack request_forgery_protection.rb
  ↓
requires: rack/session/abstract/id
  ↓
FAILS: cannot load file
```

## The Workaround

**For YOUR app only:**
1. Disable Bootsnap (doesn't fix issue, but one less complexity)
2. Disable eager loading (`config.eager_load = false` in production)

This allows production mode to start but has performance trade-offs.

## The Mystery - SOLVED

**Why did a fresh Rails 8.1 app work but the existing app didn't?**

**Answer:** Fresh Rails apps don't have custom code in `lib/`. The existing app had developer tooling in `lib/link_radar/tooling/` and `lib/link_radar/sample_data/` that was being eager-loaded, triggering the bug.

The tooling code contained patterns that, when eager-loaded, caused Ruby 3.4's `bundled_gems.rb` require wrapper to conflict with Zeitwerk's require patching.

## Solution Implemented

### Steps Taken
1. Identified that `lib/link_radar/` was being eager-loaded via bisection
2. Created `lib/dev/` directory for development utilities
3. Moved `lib/link_radar/tooling/` → `lib/dev/tooling/`
4. Moved `lib/link_radar/sample_data/` → `lib/dev/sample_data/`
5. Updated `config.autoload_lib(ignore: %w[assets tasks dev])`
6. Updated bin scripts to require from new location
7. Tested production and development modes - both work perfectly

## Should You File A Bug?

**NO** - This was not a Ruby 3.4 or Rails 8.1 bug. This was an application configuration issue where developer tooling was inadvertently being autoloaded. The proper solution is to organize lib/ directory structure with appropriate ignore rules.

## Files To Review

- `/Users/steve/src/link-radar/backend/config/initializers/cors.rb` - references `CoreConfig`
- `/Users/steve/src/link-radar/backend/config/configs/core_config.rb` - anyway_config setup
- Any other custom boot-time code

## Final Working Configuration

```ruby
# config/application.rb line 33
config.autoload_lib(ignore: %w[assets tasks dev])

# config/boot.rb
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "bootsnap/setup" # ✅ ENABLED

# config/environments/production.rb  
config.eager_load = true # ✅ ENABLED (production default)
```

Production server boots successfully with all default settings.

### Best Practice Learned

Keep developer tooling separate from runtime code:
- Use `lib/dev/` (or similar) for scripts and development utilities
- Add to autoload ignore list
- Reserve `lib/your_app_name/` for actual runtime modules

---

## Reproduction Proof

The root cause was definitively proven by reproducing the bug in a fresh Rails 8.1 app:

**Test:** Created `lib/test_rails_bug/bad_pattern.rb` with top-level `Bundler.inline`:
```ruby
require "bundler/inline"
gemfile do
  gem "dotenv"
end
```

**Results:**
- ❌ Production mode: **FAILED** with `LoadError: rack/session/abstract/id` (exact same error!)
- ✅ Development mode: Worked fine
- ✅ After moving to `lib/dev/` (ignored): Production worked
- ✅ After refactoring (Bundler.inline inside method): Production worked

**Conclusion:** Top-level `Bundler.inline` in autoloaded files is the definitive trigger for this bug. Not a Ruby or Rails issue—it's about proper code organization.

