# Ruby's `module_function`: When and Why to Use It

## The Problem

You need to organize sample data generation for your Rails app. You want clean, composable code that's easy to call:

```ruby
LinkRadar::SampleData.populate :links
LinkRadar::SampleData.populate :users
LinkRadar::SampleData.populate :comments
```

But how do you structure this? Let's look at three approaches.

## Approach 1: Classes with Inheritance

Your first instinct might be classes:

```ruby
class BaseGenerator
  def call
    raise NotImplementedError
  end
end

class LinksGenerator < BaseGenerator
  def call(success: 70, pending: 20, failed: 10)
    # Create links...
  end
end

# Usage - awkward!
LinksGenerator.new.call
```

**Problems:**
- Need to instantiate objects for stateless functions
- Unnecessary inheritance hierarchy
- More boilerplate

## Approach 2: Class Methods

Skip inheritance, use class methods:

```ruby
class LinksGenerator
  def self.call(success: 70, pending: 20, failed: 10)
    # Create links...
  end
  
  def self.create_successful_links(count)
    # ...
  end
  
  def self.create_pending_links(count)
    # ...
  end
  
  def self.create_failed_links(count)
    # ...
  end
end

# Usage
LinksGenerator.call
```

**Problems:**
- Lots of `self.` everywhere (not a huge deal, but noisy)
- Still treating it like a class when it's really just a namespace for functions

## Approach 3: Module with `module_function`

This is where `module_function` shines:

```ruby
module LinkRadar
  module SampleData
    module Links
      module_function
      
      def call(success: 70, pending: 20, failed: 10)
        create_successful_links(success)
        create_pending_links(pending)
        create_failed_links(failed)
      end
      
      def create_successful_links(count)
        # Create successful links...
      end
      
      def create_pending_links(count)
        # Create pending links...
      end
      
      def create_failed_links(count)
        # Create failed links...
      end
    end
  end
end

# Usage
LinkRadar::SampleData::Links.call
```

**Benefits:**
- No `self.` everywhere - cleaner to read
- No instantiation needed
- Clear signal: "This is a collection of related functions, not an object"
- Works perfectly with a dispatcher pattern

## The Real Win: The Dispatcher Pattern

Here's where it gets elegant. With modules, you can build a simple dispatcher:

```ruby
module LinkRadar
  module SampleData
    module_function
    
    def populate(type, **options)
      # Convert :links to LinkRadar::SampleData::Links
      generator = const_get(type.to_s.camelize)
      generator.call(**options)
    end
  end
end

# Now this just works:
LinkRadar::SampleData.populate :links
LinkRadar::SampleData.populate :users, count: 100
LinkRadar::SampleData.populate :comments, user_id: 42
```

Each generator is an independent module under `LinkRadar::SampleData::`. No inheritance. No coupling. Just functions.

## When NOT to Use `module_function`

Don't use it when you have:
- **State to manage**: If your generator needs instance variables, use a class
- **Multiple instances**: If you need different configurations per instance
- **Lifecycle methods**: If you need `initialize`, `before`, `after` callbacks

Example - when to use a class instead:

```ruby
# BAD - trying to use state with module_function
module BadGenerator
  module_function
  
  def setup(config)
    @config = config  # This won't work as you expect!
  end
  
  def call
    # @config is not accessible here
  end
end

# GOOD - use a class for state
class GoodGenerator
  def initialize(config)
    @config = config
  end
  
  def call
    # @config works perfectly
  end
end
```

## The Bottom Line

Use `module_function` when you're writing **stateless utility functions** that belong together conceptually. It's Ruby's way of saying:

> "This isn't an object. It's a namespace for related functions."

Think of it like Ruby's `Math` module:

```ruby
Math.sqrt(16)   # => 4.0
Math.sin(0)     # => 0.0
```

You don't write `Math.new.sqrt(16)` because `Math` isn't an object - it's a collection of mathematical functions. Same principle applies to your sample data generators.

## Real Example: LinkRadar Sample Data

Here's the actual structure from LinkRadar:

```
lib/
  link_radar/
    sample_data.rb           # Main module with populate dispatcher
    sample_data/
      links.rb               # Generator module
      users.rb               # Generator module (future)
      comments.rb            # Generator module (future)
```

Each generator is independent. The main module just dispatches. Clean, simple, composable.

```ruby
# sample_data.rb
module LinkRadar
  module SampleData
    module_function
    
    def populate(type, **options)
      const_get(type.to_s.camelize).call(**options)
    end
  end
end

# sample_data/links.rb
module LinkRadar::SampleData::Links
  module_function
  
  def call(success: 70, pending: 20, failed: 10)
    # Generate sample links...
  end
end

# Usage in rake task
task :sample_data do
  LinkRadar::SampleData.populate :links
end
```

No classes. No inheritance. No instances. Just functions organized in modules.

---

**TL;DR**: Use `module_function` when you're writing stateless utility functions. It's cleaner than classes and signals intent clearly. Perfect for generators, transformers, calculators, and other functional code.

