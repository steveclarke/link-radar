# State Machines Guide

## Quick Overview

State machines model object state transitions with:
- **History tracking** - Complete audit trail of all state changes
- **Transition validation** - Guards prevent invalid transitions
- **Callbacks** - Execute business logic before/after transitions
- **Metadata storage** - Store context about why transitions occurred
- **Query support** - Efficient queries by current state

## Generator Usage

Generate a complete state machine with one command:

```bash
rails generate link_radar:state_machine ModelName pending:initial success failed
```

**Components created:**
- State machine class (`app/state_machines/model_name_state_machine.rb`)
- Transition model (`app/models/model_name_transition.rb`)
- Migration for transitions table
- Factory for testing
- Comprehensive test specs

## State Syntax

States can be specified with an optional `:initial` flag:

```bash
# Explicit initial state
rails generate link_radar:state_machine Link pending:initial success failed

# First state becomes initial automatically
rails generate link_radar:state_machine Link draft active archived

# Default: draft:initial, active
rails generate link_radar:state_machine Link
```

## Basic Usage

**Check current state:**
```ruby
link.state_machine.current_state
# => "pending"
```

**Transition to new state:**
```ruby
link.state_machine.transition_to!(:success)
```

**Check allowed transitions:**
```ruby
link.state_machine.allowed_transitions
# => ["success", "failed"]
```

**Query by state:**
```ruby
Link.in_state(:pending)
Link.not_in_state(:failed)
```

## Transitions

By default, the generator creates linear transitions (initial → next → next). Customize in the state machine class:

```ruby
class LinkStateMachine
  include Statesman::Machine

  state :pending, initial: true
  state :success
  state :failed

  # Default: linear progression
  transition from: :pending, to: [:success, :failed]

  # Add custom transitions
  transition from: :failed, to: :pending  # Allow retry
end
```

## Guards

Prevent invalid transitions with guards:

```ruby
class LinkStateMachine
  guard_transition(from: :pending, to: :success) do |link, transition|
    link.fetched_at.present?
  end
end
```

Failed guards raise `Statesman::GuardFailedError`:
```ruby
link.state_machine.transition_to!(:success)
# => Statesman::GuardFailedError
```

## Callbacks

Execute business logic during transitions:

```ruby
class LinkStateMachine
  after_transition(from: :pending, to: :success) do |link, transition|
    LinkAnalysisJob.perform_later(link.id)
  end

  before_transition(from: :pending, to: :failed) do |link, transition|
    link.fetched_at = Time.current
  end
end
```

## Metadata

Store contextual information with transitions:

```ruby
link.state_machine.transition_to!(:success, {
  reason: "fetch_completed",
  fetched_by: "system",
  fetch_duration_ms: 1234
})

# Access later
transition = link.link_transitions.last
transition.metadata["reason"]  # => "fetch_completed"
```

**Common metadata patterns:**
- `performed_by_type` / `performed_by_id` - Who made the transition
- `reason` - Why the transition occurred
- `source` - API, background job, etc.
- External system references

## State Machine Class Location

State machines live in `app/state_machines/`:
- `app/state_machines/link_state_machine.rb`
- `app/state_machines/model_name_state_machine.rb`

## Transition History

Access full transition history:

```ruby
link.state_machine.history
# => [transition1, transition2, transition3]

link.state_machine.last_transition
# => most recent transition
```

## Model Integration

The generator automatically adds to your model:
- `has_many :model_transitions`
- `include Statesman::Adapters::ActiveRecordQueries`
- `state_machine` method
- Delegate methods: `current_state`, `can_transition_to?`, `transition_to!`, `allowed_transitions`

## Testing

Generated specs include:
- State definitions
- Transition behavior
- Database integration
- Error handling

**Test guards:**
```ruby
expect { link.state_machine.transition_to!(:success) }
  .to raise_error(Statesman::GuardFailedError)
```

**Test callbacks:**
```ruby
expect { link.state_machine.transition_to!(:success) }
  .to change { link.reload.some_attribute }.by(1)
```

## Key Differences from Rails Enums

Statesman provides:
- ✅ Complete transition history
- ✅ Metadata storage
- ✅ Guard validation
- ✅ Callbacks
- ✅ Audit trail

Rails enums provide:
- ✅ Simple state storage
- ✅ Faster queries (denormalized)

**Recommendation:** Use Statesman for complex workflows, enums for simple flags.

## Common Patterns

**Cascade deletion:**
```ruby
class Link < ApplicationRecord
  has_many :link_transitions, dependent: :destroy
end
```

**Storing current state on model (optional):**
```ruby
class LinkStateMachine
  after_transition(after_commit: true) do |link, transition|
    link.fetch_state = transition.to_state
    link.save!
  end
end
```

## Reference

- **Statesman gem:** https://github.com/gocardless/statesman
- **State machine class:** `app/state_machines/`
- **Transition model:** `app/models/*_transition.rb`
- **Generator:** `rails generate link_radar:state_machine`

