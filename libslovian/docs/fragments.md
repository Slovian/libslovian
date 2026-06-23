# Fragment System

Composable component system for Defold game objects. A game object's `.script` becomes a thin host; behavior lives in reusable fragments.

## Core files

- `libslovian.defold.fragment.Fragment` — base class
- `libslovian.defold.fragment.FragmentsCollection` — composition manager
- `libslovian.defold.fragment.FsmFragment` — adapter for FSM-based fragments
- `libslovian.defold.fragment.DynamicFragment` — fragments added/removed at runtime
- `libslovian.defold.fragment.DynamicModulesFragment` — host fragment that owns dynamic children
- `libslovian.defold.fragment.collections.baseCollection` — generic membership collection
- `libslovian.defold.fragment.collections.TraitsCollection` — trait-aware membership collection

## Concept

A **fragment** is a reusable component attached to a game object. It mirrors Defold lifecycle hooks: `init`, `final`, `update`, `on_message`, `on_input`. Fragments register only the callbacks they need.

A **FragmentsCollection** owns all fragments on one game object, forwards engine events in dependency order, provides a shared blackboard, and exposes a context API during `init`.

## Wiring a script

```lua
local FragmentsCollection = require("libslovian.defold.fragment.FragmentsCollection")
local SomeFragment = require("...")

function init(self)
    local fragments = FragmentsCollection:new(self)
    fragments:addFragment(SomeFragment:new(self))
    self.mFragments = fragments
    fragments:init(
        { ... },                       -- definition table passed to each fragment
        { spawnProperties = { ... } }  -- optional, available as context.spawnProperties
    )
end

function final(self)        self.mFragments:final() end
function update(self, dt)   self.mFragments:update(dt) end
function on_message(...)    self.mFragments:on_message(...) end
function on_input(...)      self.mFragments:on_input(...) end
```

The collection installs `self.internal_message(id, message)` on the owner so fragments can broadcast to sibling fragments.

## Writing a fragment

```lua
local Fragment = require("libslovian.defold.fragment.Fragment")

local MyFragment = Fragment:extend()

function MyFragment:init(context)
    -- Register callbacks you need.
    context.registerOnUpdate()
    context.registerOnMessage()
    context.registerOnInternalMsg()
    context.registerOnInput()

    -- Shared blackboard across fragments on this game object.
    local bb = context.getBlackboard()
    bb.MyData = 42
    self.mBlackboard = bb
end

function MyFragment:update(dt) end
function MyFragment:on_message(message_id, message, sender) end
function MyFragment:on_internal_message(internal_id, message) end
function MyFragment:on_input(action_id, action) end
function MyFragment:final() end

return MyFragment
```

`self.mOwner` is the game-object `self` table.
`Fragment:internal_message(id, message)` broadcasts to all fragments on the same owner.

## Context API (available only in `Fragment:init`)

| Function | Purpose |
|---|---|
| `context.definition` | The table passed to `FragmentsCollection:init(definition)`. |
| `context.getBlackboard()` | Returns shared fragment blackboard; lazy-created. |
| `context.getDependency(FragmentClass)` | Returns the already-created fragment instance of class `FragmentClass`, or `nil`. |
| `context.initDependency(FragmentClass)` | Forces initialization of a later fragment early if your fragment needs it during init. |
| `context.registerOnUpdate()` | Adds this fragment to the ordered `update` callback list. |
| `context.registerOnMessage()` | Adds this fragment to the ordered `on_message` callback list. |
| `context.registerOnInternalMsg()` | Adds this fragment to the ordered `on_internal_message` callback list. |
| `context.registerOnInput()` | Adds this fragment to the ordered `on_input` callback list. |
| `context.registerPostInit()` | Triggers `hash("post_init")` to be sent to `#script` after all fragments init. |
| `context.spawnProperties` | Optional properties table passed in `FragmentsCollection:init` options. |

## Blackboard conventions

- Use `context.getBlackboard()` for owner-level shared state.
- Store fragment-private state on `self` (e.g. `self.mTimer`).
- Blackboard keys being object 'public' attributes.

## Internal messages

Fragments communicate via `self:internal_message(id, message)`. The collection calls `on_internal_message(id, message)` on every fragment that registered for it.

Use hashed ids: `local MSG_DIE = hash("die")`.

## Dependencies

During `init`, call `context.registerOnUpdate({ dep1, dep2 })` (or message/internal/input) to declare ordering. Fragments with dependencies are sorted so dependencies run first in that callback list.

To access another fragment during init:
- Prefer `context.getDependency(OtherFragmentClass)` if already initialized.
- Use `context.initDependency(OtherFragmentClass)` to force it early if it appears later in the add order.

## FSMFragment

Wraps any FSM class that has `init`, `final`, `update`, `on_message`, `on_internal_message`, `on_input`.

```lua
local FsmFragment = require("libslovian.defold.fragment.FsmFragment")
local MyFsm = require("...")

fragments:addFragment(FsmFragment:new(self, MyFsm))
```

The FSM receives the same `context` in `fsm:init(context)`.

## Dynamic fragments

`DynamicFragment` is a `Fragment` subclass meant for fragments created and destroyed after the owner is initialized. It accepts the same `init(context, definition)` signature.

`DynamicModulesFragment` hosts a list of dynamic children, routing engine callbacks to them:

```lua
local DynamicModulesFragment = require("libslovian.defold.fragment.DynamicModulesFragment")
local MyDynamicModule = require("...")

local modules = DynamicModulesFragment:new(self)
fragments:addFragment(modules)

-- later
modules:addDynamicFragment(MyDynamicModule:new(self), dynamicContext)
modules:removeDynamicFragment(someModule)
```

The host handles `update`, `on_message`, `on_internal_message`, `on_input`, and `final` for all active children.

## Collections

`baseCollection` is a generic membership registry with versioning:

```lua
local Collection = require("libslovian.defold.fragment.collections.baseCollection")
local coll = Collection:new()
coll:registerMember(member, properties)
coll:unregisterMember(member)
```

`TraitsCollection` extends that with fast trait queries:

```lua
local TraitsCollection = require("libslovian.defold.fragment.collections.TraitsCollection")
local tc = TraitsCollection:new()
tc:registerMember(ship, {"fighter", "fast"})

for ship in tc:byTrait("fighter") do ... end
for ship in tc:matchAll({"fighter", "cloaked"}) do ... end
```

Use `libslovian.core.Traits` directly if you only need string↔id interning or bit signatures.

## AI agent guidelines

**When adding behavior to a game object:**
1. Create a new fragment extending `Fragment`.
2. Register only the callbacks it needs in `init(context)`.
3. Use `context.getBlackboard()` for cross-fragment state.
4. Use `self:internal_message(...)` for fragment-to-fragment signals.
5. Add the fragment to the host script's `FragmentsCollection`.

**Do:**
- Keep fragments focused on one responsibility.
- Store owner-level shared data in the blackboard.
- Use hashed message constants.
- Declare dependencies when order matters.

**Don't:**
- Put engine lifecycle logic directly in host scripts; forward to fragments.
- Access another fragment's private `self.*` fields; use the blackboard or internal messages.
- Forget to register callbacks in `init`; unregistered methods won't be called.
- Use `context.*` helpers outside `init`; they are only valid during initialization.
