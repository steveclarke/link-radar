# Ruby 3.4 + Zeitwerk + Eager Loading Bug Report

**Date:** November 1, 2025  
**Reporter:** Steve  
**Status:** ✅ RESOLVED

## Resolution Summary

**Root Cause:** Developer tooling code in `lib/link_radar/tooling/` and `lib/link_radar/sample_data/` was being eager-loaded in production, triggering the Ruby 3.4 + Zeitwerk + `bundled_gems.rb` conflict.

**Fix:** Reorganized lib/ directory structure:
- Moved tooling code to `lib/dev/tooling/`
- Moved sample data to `lib/dev/sample_data/`
- Updated `config.autoload_lib(ignore: %w[assets tasks dev])`

**Result:** Production boots successfully with default settings (eager_load=true, Bootsnap enabled).

---

## Executive Summary

Rails 8.1 application was failing to start in production mode (`RAILS_ENV=production`) with Ruby 3.4.7. The error manifested as `LoadError: cannot load such file -- rack/session/abstract/id` for gems that WERE installed and WERE in `$LOAD_PATH`.

## Environment

- **Ruby Version:** 3.4.7 (also reproduced on 3.4.6)
- **Rails Version:** 8.1.1
- **Platform:** macOS (darwin 25.0.0), ARM64
- **Ruby Manager:** mise (previously asdf-compatible)
- **Bundler Version:** 2.6.2
- **Zeitwerk Version:** 2.7.3
- **Bootsnap Version:** 1.18.6

### Application Configuration
- API-only Rails app (`config.api_only = true`)
- Includes JBuilder gem (requires ActionView::Railtie)
- ActionView loaded explicitly in `config/application.rb`
- PostgreSQL database (pg gem)

## Symptoms

### Initial Error
```
/Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'Kernel.require': 
cannot load such file -- rack/session/abstract/id (LoadError)
```

### Subsequent Errors (as we manually added gems)
```
cannot load such file -- erubi (LoadError)
cannot load such file -- pg (LoadError)
```

### Key Observations
1. ✅ **Works in development mode** (`RAILS_ENV=development`)
2. ❌ **Fails in production mode** (`RAILS_ENV=production`)
3. ✅ **Gems ARE installed** (verified via `bundle list`)
4. ✅ **Files exist in $LOAD_PATH** (verified manually)
5. ✅ **Manual require works** (`bundle exec ruby -e "require 'rack/session/abstract/id'"` succeeds)
6. ❌ **Fails during Rails eager loading** (when `config.eager_load = true`)

## Root Cause Analysis

### The Three-Way Conflict

1. **Ruby 3.4's `bundled_gems.rb`**
   - Located: `lib/ruby/3.4.0/bundled_gems.rb`
   - Wraps `Kernel#require` to warn about gems extracted from stdlib
   - Creates alias: `no_warning_require` → original `require`
   - New `require` calls `no_warning_require` after checking for warnings

2. **Zeitwerk's require patching**
   - Located: `gems/zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb`
   - Wraps `Kernel#require` for autoloading interception
   - Creates alias: `zeitwerk_original_require` → original `require`
   - New `require` calls `zeitwerk_original_require` after autoload checks

3. **The Conflict**
   - When both patches are active, the alias chain breaks
   - During eager loading, Zeitwerk's `zeitwerk_original_require` calls a version of `require` that doesn't have proper gem resolution
   - Ruby's `bundled_gems.rb` wrapper then fails to find gems that Bundler has made available

### Why Development Works But Production Fails

- **Development:** `config.eager_load = false` → classes load on-demand → conflict path rarely triggered
- **Production:** `config.eager_load = true` → loads ActionController::Base → includes RequestForgeryProtection → requires `rack/session/abstract/id` → hits the broken require chain

### Critical Stack Trace Analysis

```
bundled_gems.rb:82:in 'Kernel.require'                          # Ruby's wrapper
bundled_gems.rb:82:in 'block (2 levels) in Kernel#replace_require'
zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb:34:in 'Kernel#require'  # Zeitwerk's wrapper
actionpack-8.1.1/lib/action_controller/metal/request_forgery_protection.rb:5
```

The stack shows both wrappers are active and conflicting.

## What We Tried (And Why Each Failed)

### 1. ❌ Clearing Bootsnap Cache
```bash
rm -rf tmp/cache
```
**Why it failed:** Not a Bootsnap issue; the conflict exists without Bootsnap

### 2. ❌ Adding Gems Manually to Gemfile
```ruby
gem "rack-session"
gem "erubi"
```
**Why it failed:** Gems were already present as transitive dependencies; manually adding them doesn't fix the require chain

### 3. ❌ Forcing Bundler.require in config/boot.rb
```ruby
if ENV["RAILS_ENV"] == "production"
  Bundler.require(:default, :production)
end
```
**Why it failed:** Gems are loaded but the require patching conflict remains

### 4. ❌ Manually Adding to $LOAD_PATH
```ruby
Bundler.load.specs.each do |spec|
  spec.full_require_paths.each do |path|
    $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
  end
end
```
**Why it failed:** Paths are correct; the problem is in the require method wrappers, not the load path

### 5. ❌ Disabling bundled_gems.rb Wrapper
```ruby
if Kernel.respond_to?(:no_warning_require, true)
  Kernel.singleton_class.send(:alias_method, :require, :no_warning_require)
  Kernel.send(:alias_method, :require, :no_warning_require)
end
```
**Why it failed:** Zeitwerk's wrapper still references the broken chain

### 6. ❌ Re-aliasing Zeitwerk's require
```ruby
Kernel.send(:alias_method, :zeitwerk_original_require, :require)
```
**Why it failed:** Created infinite recursion loop

### 7. ❌ Downgrading to Ruby 3.3.6
**Why it failed:** Wait, we tried this and it SHOULD have worked, but the issue persisted (this suggests the problem might be more complex than just Ruby 3.4)

## ✅ Working Workaround

### Configuration Changes

**File: `config/boot.rb`**
```ruby
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
# require "bootsnap/setup" # Speed up boot time by caching expensive operations.
```
- Disabled Bootsnap in production

**File: `config/environments/production.rb`**
```ruby
# Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
# TEMPORARILY disabled due to Ruby 3.4 + Zeitwerk + bundled_gems.rb conflict
# TODO: Re-enable once Ruby/Zeitwerk fix is available
config.eager_load = false
```
- Disabled eager loading in production

### Trade-offs
- ❌ Boot time: ~1-3 seconds slower (no Bootsnap)
- ❌ First request: Slower (classes load on-demand)
- ❌ Memory: Higher over time (classes stay loaded)
- ❌ Error detection: Boot-time errors not caught before serving traffic
- ❌ Thread safety: Potential issues with on-demand loading in multi-threaded environments

### Verification
```bash
RAILS_ENV=production bin/rails s
# Server starts successfully
```

## Steps to Reproduce

### Minimal Reproduction Case

1. Create new Rails 8.1 API-only app:
   ```bash
   rails new myapp --api
   cd myapp
   ```

2. Add JBuilder (requires ActionView):
   ```bash
   bundle add jbuilder
   ```

3. Ensure ActionView is loaded in `config/application.rb`:
   ```ruby
   require "action_view/railtie"
   ```

4. Set Ruby version to 3.4.7:
   ```bash
   mise use ruby@3.4.7
   bundle install
   ```

5. Try to start in production:
   ```bash
   RAILS_ENV=production bin/rails s
   ```

**Expected:** Server starts  
**Actual:** LoadError for `rack/session/abstract/id`

## Why This Is Rare

Most developers haven't hit this because:

1. **Ruby 3.4 adoption is recent** (released Dec 2024)
2. **Rails 8.1 is brand new** (released Oct 2025)
3. **API-only apps typically don't include ActionView/JBuilder**
4. **Most production apps are still on Ruby 3.3.x**
5. **The combination API-only + JBuilder + ActionView + Ruby 3.4 + eager loading is uncommon**

## Evidence This Is A Real Bug

### Manual require works:
```bash
$ RAILS_ENV=production bundle exec ruby -e "require 'rack/session/abstract/id'; puts 'OK'"
OK
```

### File exists in load path:
```bash
$ RAILS_ENV=production bundle exec ruby -e "
  require_relative 'config/boot'
  puts \$LOAD_PATH.grep(/rack-session/).any? { |p| 
    File.exist?(File.join(p, 'rack/session/abstract/id.rb'))
  }
"
true
```

### Eager loading fails:
```bash
$ RAILS_ENV=production bundle exec ruby -e "
  require_relative 'config/boot'
  require_relative 'config/application'
  Rails.application.initialize!
"
LoadError: cannot load such file -- rack/session/abstract/id
```

## Relevant Ruby/Zeitwerk Code

### bundled_gems.rb (Ruby 3.4.7)
Line 70-85:
```ruby
def self.replace_require(specs)
  return if [::Kernel.singleton_class, ::Kernel].any? {|klass| klass.respond_to?(:no_warning_require) }

  spec_names = specs.to_a.each_with_object({}) {|spec, h| h[spec.name] = true }

  [::Kernel.singleton_class, ::Kernel].each do |kernel_class|
    kernel_class.send(:alias_method, :no_warning_require, :require)
    kernel_class.send(:define_method, :require) do |name|
      if message = ::Gem::BUNDLED_GEMS.warning?(name, specs: spec_names)
        uplevel = ::Gem::BUNDLED_GEMS.uplevel
        if uplevel > 0
          Kernel.warn message, uplevel: uplevel
        else
          Kernel.warn message
        end
      end
      kernel_class.send(:no_warning_require, name)  # LINE 82 - Where it fails
    end
```

### zeitwerk/core_ext/kernel.rb (Zeitwerk 2.7.3)
Line 16-42:
```ruby
alias_method :zeitwerk_original_require, :require
class << self
  alias_method :zeitwerk_original_require, :require
end

def require(path)
  if loader = Zeitwerk::Registry.autoloads.registered?(path)
    if path.end_with?(".rb")
      required = zeitwerk_original_require(path)  # Calls broken require chain
      loader.__on_file_autoloaded(path) if required
      required
    else
      loader.__on_dir_autoloaded(path)
      true
    end
  else
    required = zeitwerk_original_require(path)
    if required
      abspath = $LOADED_FEATURES.last
      if loader = Zeitwerk::Registry.autoloads.registered?(abspath)
        loader.__on_file_autoloaded(abspath)
      end
    end
    required
  end
end
```

## Where to Report

### Primary: Ruby Bug Tracker
- **URL:** https://bugs.ruby-lang.org/
- **Issue:** `bundled_gems.rb` require wrapper conflicts with other require patches (Zeitwerk)
- **Component:** stdlib/bundled_gems
- **Version:** Ruby 3.4.6, 3.4.7

### Secondary: Zeitwerk Issues
- **URL:** https://github.com/fxn/zeitwerk/issues
- **Context:** Zeitwerk's require wrapper doesn't handle Ruby 3.4's bundled_gems wrapper
- **Note:** This might be a Ruby bug, not Zeitwerk's fault

### Tertiary: Rails Issues
- **URL:** https://github.com/rails/rails/issues
- **Context:** Rails eager loading triggers the conflict
- **Note:** Likely not a Rails bug, but Rails is where users encounter it

## Questions for Bug Report

1. **Is this a known issue?** Search existing bugs first
2. **Is the bundled_gems.rb wrapper design compatible with other require patches?**
3. **Should Zeitwerk handle this differently?**
4. **Is there a recommended way to patch require that works with bundled_gems.rb?**
5. **Why does Ruby 3.3 not have this issue?** (Or does it and we missed something?)

## Additional Testing Needed

- [ ] Test with Ruby 3.3.x to confirm it works there
- [ ] Test with a non-API-only Rails 8.1 app
- [ ] Test without JBuilder/ActionView
- [ ] Test with Zeitwerk disabled (if possible)
- [ ] Test with an older Zeitwerk version
- [ ] Check if Ruby 3.4.0-3.4.5 have the same issue
- [ ] Test on different platforms (Linux, other macOS versions)

## Related Links

- Ruby 3.4.0 Release Notes: https://www.ruby-lang.org/en/news/2024/12/25/ruby-3-4-0-released/
- Rails 8.1 Release Notes: https://rubyonrails.org/
- Zeitwerk Documentation: https://github.com/fxn/zeitwerk
- Bundled Gems in Ruby: https://stdgems.org/

## Contact Info

- GitHub: (your GitHub handle)
- Email: (your email if you want to include it)
- Project: Link Radar (private project)

---

## Appendix: Full Error Stack Trace

```
/Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'Kernel.require': cannot load such file -- rack/session/abstract/id (LoadError)
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'block (2 levels) in Kernel#replace_require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb:34:in 'Kernel#require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/metal/request_forgery_protection.rb:5:in '<top (required)>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'Kernel.require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'block (2 levels) in Kernel#replace_require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb:34:in 'Kernel#require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/base.rb:252:in '<class:Base>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/base.rb:208:in '<module:ActionController>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/base.rb:10:in '<top (required)>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'Kernel.require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'block (2 levels) in Kernel#replace_require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb:34:in 'Kernel#require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/railtie.rb:92:in 'block (3 levels) in <class:Railtie>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/railtie.rb:88:in 'Hash#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/railtie.rb:88:in 'block (2 levels) in <class:Railtie>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:97:in 'Module#class_eval'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:97:in 'block in ActiveSupport::LazyLoadHooks#execute_hook'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:87:in 'ActiveSupport::LazyLoadHooks#with_execution_control'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:92:in 'ActiveSupport::LazyLoadHooks#execute_hook'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:78:in 'block in ActiveSupport::LazyLoadHooks#run_load_hooks'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:77:in 'Array#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/activesupport-8.1.1/lib/active_support/lazy_load_hooks.rb:77:in 'ActiveSupport::LazyLoadHooks#run_load_hooks'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/api.rb:154:in '<class:API>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/api.rb:93:in '<module:ActionController>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/actionpack-8.1.1/lib/action_controller/api.rb:10:in '<top (required)>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'Kernel.require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'block (2 levels) in Kernel#replace_require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb:34:in 'Kernel#require'
        from /Users/steve/src/link-radar/backend/app/controllers/application_controller.rb:1:in '<top (required)>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'Kernel.require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/3.4.0/bundled_gems.rb:82:in 'block (2 levels) in Kernel#replace_require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/core_ext/kernel.rb:26:in 'Kernel#require'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/cref.rb:62:in 'Module#const_get'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/cref.rb:62:in 'Zeitwerk::Cref#get'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:173:in 'block in Zeitwerk::Loader::EagerLoad#actual_eager_load_dir'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/helpers.rb:47:in 'block in Zeitwerk::Loader::Helpers#ls'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/helpers.rb:25:in 'Array#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/helpers.rb:25:in 'Zeitwerk::Loader::Helpers#ls'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:168:in 'Zeitwerk::Loader::EagerLoad#actual_eager_load_dir'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:17:in 'block (2 levels) in Zeitwerk::Loader::EagerLoad#eager_load'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:16:in 'Hash#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:16:in 'block in Zeitwerk::Loader::EagerLoad#eager_load'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:10:in 'Thread::Mutex#synchronize'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader/eager_load.rb:10:in 'Zeitwerk::Loader::EagerLoad#eager_load'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader.rb:431:in 'block in Zeitwerk::Loader.eager_load_all'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/registry/loaders.rb:10:in 'Array#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/registry/loaders.rb:10:in 'Zeitwerk::Registry::Loaders#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/zeitwerk-2.7.3/lib/zeitwerk/loader.rb:429:in 'Zeitwerk::Loader.eager_load_all'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/application/finisher.rb:79:in 'block in <module:Finisher>'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/initializable.rb:24:in 'BasicObject#instance_exec'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/initializable.rb:24:in 'Rails::Initializable::Initializer#run'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/initializable.rb:103:in 'block in Rails::Initializable#run_initializers'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:231:in 'block in TSort.tsort_each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:353:in 'block (2 levels) in TSort.each_strongly_connected_component'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:434:in 'TSort.each_strongly_connected_component_from'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:352:in 'block in TSort.each_strongly_connected_component'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/initializable.rb:59:in 'Array#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/initializable.rb:59:in 'Rails::Initializable::Collection#each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:350:in 'Method#call'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:350:in 'TSort.each_strongly_connected_component'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:229:in 'TSort.tsort_each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/tsort-0.2.0/lib/tsort.rb:208:in 'TSort#tsort_each'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/initializable.rb:102:in 'Rails::Initializable#run_initializers'
        from /Users/steve/.local/share/mise/installs/ruby/3.4.7/lib/ruby/gems/3.4.0/gems/railties-8.1.1/lib/rails/application.rb:442:in 'Rails::Application#initialize!'
```

---

## Actual Root Cause (RESOLVED)

After systematic debugging through bisection, the actual root cause was identified:

### The Real Problem

**Developer tooling code in `lib/link_radar/` was being eager-loaded in production.**

The application had:
```
lib/
└── link_radar/
    ├── tooling/           # ❌ Being eager-loaded
    │   ├── setup_runner.rb
    │   ├── runner_support.rb
    │   ├── one_password_client.rb
    │   └── port_manager.rb
    └── sample_data/       # ❌ Being eager-loaded
        └── links.rb
```

With configuration:
```ruby
# config/application.rb
config.autoload_lib(ignore: %w[assets tasks])  # link_radar NOT ignored!
```

When production mode enabled `eager_load = true`, Rails/Zeitwerk attempted to autoload the tooling and sample_data code, which contained code patterns that triggered the Ruby 3.4 `bundled_gems.rb` + Zeitwerk conflict.

### The Technical Trigger

The specific code pattern that triggered the bug was **`Bundler.inline`** in `runner_support.rb`:

```ruby
# lib/link_radar/tooling/runner_support.rb (lines 6-11)
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "dotenv"
end
```

**What happened during eager loading:**

1. **Zeitwerk eager-loads the file** → executes all top-level code
2. **`Bundler.inline` runs immediately** → creates a second, nested Bundler context
3. **The inline gemfile tries to load dotenv** → triggers `require`
4. **Triple-wrapped require resolution:**
   - Ruby 3.4's `bundled_gems.rb` wrapper (layer 1)
   - Zeitwerk's `Kernel#require` patch (layer 2)  
   - Bundler's inline context (layer 3)
5. **Require resolution chain breaks** → `LoadError` for gems that ARE installed

**Why it worked in development:** `eager_load = false` means Zeitwerk never loaded these files, so the `Bundler.inline` code never executed.

**Other problematic patterns found:**
- Top-level `require` statements (`require "fileutils"`, `require "open3"`)
- `require_relative` chains creating circular dependencies
- Side effects during file load (the inline gemfile execution)

These patterns are **fine for standalone scripts** but violate Zeitwerk's expectations:
- No top-level code execution in autoloaded files
- No manual `require` statements (Zeitwerk handles loading)
- No side effects during file load

### Why Fresh Rails 8.1 Apps Worked

Fresh Rails apps don't have custom lib/ code, so eager loading doesn't encounter problematic code patterns. This was specific to applications with developer tooling in the lib/ directory being inadvertently autoloaded.

### The Solution

Reorganized the lib/ directory structure to properly separate development utilities from runtime code:

**Before:**
```
lib/
└── link_radar/
    ├── tooling/           # Wrongly autoloaded
    └── sample_data/       # Wrongly autoloaded
```

**After:**
```
lib/
├── dev/                   # Properly ignored
│   ├── tooling.rb        # Loader for bin scripts
│   ├── tooling/
│   │   ├── setup_runner.rb
│   │   ├── runner_support.rb
│   │   ├── one_password_client.rb
│   │   └── port_manager.rb
│   └── sample_data/
│       └── links.rb
└── link_radar/           # Clean, ready for runtime code
    └── .keep
```

**Configuration change:**
```ruby
# config/application.rb line 33
config.autoload_lib(ignore: %w[assets tasks dev])
```

**Bin scripts updated:**
```ruby
# bin/dev, bin/setup, bin/services
require_relative "../lib/dev/tooling"  # Updated path
```

### Final Result

✅ Production boots successfully with:
- `config.eager_load = true` (production default)
- Bootsnap enabled (production default)
- All gems intact (jbuilder, anyway_config, rack-cors, etc.)
- Ruby 3.4.7
- Rails 8.1.1

### Key Takeaway

**This was NOT a Ruby 3.4 or Rails 8.1 bug.** It was an application configuration issue where developer tooling was incorrectly being included in the autoload/eager-load paths. The solution is proper lib/ directory organization with appropriate autoload ignore rules.

### Best Practice

Keep developer tooling separate from runtime code:
- Use `lib/dev/` or similar for scripts, generators, and development utilities
- Add to autoload ignore list: `config.autoload_lib(ignore: %w[assets tasks dev])`
- Reserve `lib/your_app_name/` for actual runtime modules and classes

### Refactoring: From Script-Style to Proper Modules

After identifying the issue, the dev tooling code was refactored to eliminate top-level execution:

**Changes made:**
1. **runner_support.rb** - Moved `Bundler.inline` gemfile block into `load_env_file` method with try/rescue fallback
2. **setup_runner.rb** - Moved `require "fileutils"` and `require "io/console"` into methods that use them
3. **one_password_client.rb** - Moved `require "open3"` into the `fetch` method
4. **port_manager.rb** - Moved `require "socket"` into the `port_in_use?` method

**Result:** All files now define pure modules/classes with no top-level execution. Bootstrap functionality is preserved (dependencies are loaded when methods are called), and the code would be safe to autoload (though it remains in the ignored `lib/dev/` directory).

### Lessons Learned: Scripts vs Modules

**The Problem:** These tooling files were "scripts disguised as modules" - they contained:
- Top-level executable code (`Bundler.inline` gemfile blocks)
- Script-like `require` statements for stdlib gems
- Side effects during file load
- Code meant to be directly executed, not autoloaded

**Zeitwerk-Compatible Modules:**
```ruby
# ✅ Good: Pure module/class definition, no top-level execution
module MyApp
  class MyService
    def call
      # All logic is in methods, executed only when called
      require_something if needed  # Conditional requires inside methods are OK
    end
  end
end
```

**Script-Style Code (Don't Autoload):**
```ruby
# ❌ Bad for autoloading: Top-level execution, Bundler.inline
require "bundler/inline"

gemfile do
  gem "dotenv"  # This EXECUTES when file is loaded!
end

module MyApp
  module Tooling
    # Even if wrapped in modules, the top-level code executes
  end
end
```

**Key Insight:** If your file has top-level `require` statements or executable code outside of method definitions, it's a script and should NOT be in Zeitwerk's autoload paths. These belong in `lib/dev/`, `lib/tasks/`, or potentially outside `lib/` entirely (e.g., `scripts/`, `bin/support/`).

**Warning Signs Your Code Shouldn't Be Autoloaded:**
- Uses `Bundler.inline` 
- Has top-level `require` for stdlib gems (`fileutils`, `open3`, etc.)
- Executes code during file load (not just defining classes/modules)
- Designed to be run by bin scripts, not loaded by Rails
- Uses `$stdout.puts` or other direct I/O (typical of scripts, not modules)

---

## Reproduction Proof

To definitively prove the root cause, the bug was successfully reproduced in a fresh Rails 8.1 app:

### Test Setup
1. Created fresh Rails 8.1.1 API-only app with Ruby 3.4.7
2. Added file `lib/test_rails_bug/bad_pattern.rb` with top-level `Bundler.inline`:
```ruby
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "dotenv"
end

module TestRailsBug
  module BadPattern
    # ...
  end
end
```

### Results

| Scenario | File Location | Pattern | Production Boot | Development Boot |
|----------|--------------|---------|-----------------|------------------|
| **BAD** | `lib/test_rails_bug/bad_pattern.rb` (autoloaded) | Top-level `Bundler.inline` | ❌ **FAILS** - `LoadError: rack/session/abstract/id` | ✅ Works |
| **FIXED** | `lib/dev/bad_pattern.rb` (ignored from autoload) | Same code, not autoloaded | ✅ Works | ✅ Works |
| **GOOD** | `lib/test_rails_bug/good_pattern.rb` (autoloaded) | `Bundler.inline` inside method | ✅ Works | ✅ Works |

### Conclusion

**The bug was perfectly reproduced** in a fresh app, confirming:
1. Top-level `Bundler.inline` in autoloaded files triggers the exact same `LoadError`
2. Moving to ignored directory (`lib/dev/`) fixes the issue
3. Refactoring to move `Bundler.inline` inside methods fixes the issue
4. The problem is **not** a Ruby 3.4 or Rails 8.1 bug, but a code organization issue

**Root cause confirmed:** Top-level executable code (particularly `Bundler.inline`) in Zeitwerk-autoloaded files creates nested require contexts that break Ruby 3.4's `bundled_gems.rb` require wrapper during eager loading.

