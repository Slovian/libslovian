# FSM System

Three FSM variants share the same state/transition model but target different hosts.

| Variant | Host | Use case |
|---|---|---|
| `ScriptFsm` | Plain `.script` | Game-object behavior driven by FSM; script forwards lifecycle to FSM. |
| `FsmFragment` | Fragment collection | An FSM lives as one fragment among others. |
| `GuiFsm` | `.gui_script` | GUI screens with stateful flows (menus, popups, HUD modes). |

All use:
- state ids (anything hashable, commonly numbers or hashes)
- `activate(prev)` / `deactivate(next)` entry/exit hooks
- handlers returning an optional next-state id to transition

---

## ScriptFsm

Define an FSM class, instantiate it in a script, forward engine callbacks.

```lua
local ScriptFsm = require("libslovian.defold.fsm.ScriptFsm")

local STATE_IDLE = 1
local STATE_ACTIVE = 2

local FSM = ScriptFsm:defineFsm(STATE_IDLE)

FSM:addInitializer(function(vars, owner, context)
    vars.counter = 0
end)

local idle = FSM:addState(STATE_IDLE)
idle.activate = function(vars, owner, prev)
    print("idle")
end
idle.update = function(vars, owner, dt)
    vars.counter = vars.counter + dt
    if vars.counter > 1 then
        return STATE_ACTIVE
    end
end

local active = FSM:addState(STATE_ACTIVE)
active.activate = function(vars, owner, prev)
    print("active")
end

-- script host
function init(self)
    self.mFsm = FSM:new(self)
    self.mFsm:init()
end
function final(self)       self.mFsm:final() end
function update(self, dt)  self.mFsm:update(dt) end
function on_message(...)   self.mFsm:on_message(...) end
function on_input(...)     self.mFsm:on_input(...) end
```

### ScriptFsm API

- `ScriptFsm:defineFsm(startingState)` — create FSM class.
- `fsm:addInitializer(init_fn, final_fn)` — called on `fsm:init` / `fsm:final`.
- `fsm:addState(id, update, on_message, activate, deactivate, on_input, on_internal_message)` — returns state table.
- `fsm:extend(newStartingState)` — fork FSM class; states are shallow-copied.
- `fsm:overrideState(id)` — clone one state for local override; original kept in `state.super`.
- `fsm:setState(id)` — explicit transition.
- Instance: `init(context)`, `final()`, `update(dt)`, `on_message(...)`, `on_input(...)`, `on_internal_message(...)`.

Handler signatures: `fn(vars, owner, ...)` where `vars` is `mStateVariables` table.

---

## GuiFsm

State-oriented FSM for GUI scripts. Each state is an object; handlers receive the state as `self`.

```lua
local GuiFsm = require("libslovian.defold.fsm.GuiFsm")

local FsmClass = GuiFsm.defineFsm("hidden")

FsmClass:addInitializer(function(vars)
    vars.clicks = 0
end)

local hidden = FsmClass:addState("hidden")
function hidden:activate(prev_id)
    gui.set_enabled(gui.get_node("panel"), false)
end
function hidden:on_message(message_id, message, sender)
    if message_id == hash("show") then
        return "visible"
    end
end

local visible = FsmClass:addState("visible", { flags = { speed = 2 } })
function visible:activate(prev_id)
    gui.set_enabled(gui.get_node("panel"), true)
end
function visible:update(dt)
    if self:flag("speed") > 1 then
        -- state-local logic
    end
end
function visible:on_input(action_id, action)
    if action_id == hash("touch") and action.pressed then
        self:goTo("hidden")
    end
end

-- gui_script host
function init(self)
    self.mFsm = FsmClass:new(self)
    self.mFsm:init()
end
function final(self)       self.mFsm:final() end
function update(self, dt)  self.mFsm:update(dt) end
function on_message(...)   self.mFsm:on_message(...) end
function on_input(...)     self.mFsm:on_input(...) end
```

### GuiFsm state helpers

Inside state handlers, `self` is the state instance:
- `self:id()` — state id.
- `self:owner()` — GUI `self` table.
- `self:vars()` — shared `fsm.vars` bag.
- `self:flag(name, default)` — read state flag from `state_proto.flags`.
- `self:goTo(state_id)` — queue/request transition.

### GuiFsm API

- `GuiFsm.defineFsm(initial_state_id)` — returns FsmClass.
- `FsmClass:addInitializer(init_fn, final_fn)` — global init/final hooks on `vars`.
- `FsmClass:addState(id, state_proto)` — returns state prototype table.
- `FsmClass:new(owner)` — create live instance bound to GUI `self`.
- Instance: `init()`, `final()`, `update(dt)`, `on_message(...)`, `on_input(...)`, `internal_message(...)`.
- Query: `fsm:state_id()`, `fsm:state()`, `fsm:flag(name, default)`.

Transitions triggered from inside a handler can be returned or queued with `self:goTo`. Both are applied after the handler exits.

---

## FsmFragment

Bridges an FSM class into the fragment system. The FSM can be either `ScriptFsm` or any class with the same lifecycle methods.

```lua
local FragmentsCollection = require("libslovian.defold.fragment.FragmentsCollection")
local FsmFragment = require("libslovian.defold.fragment.FsmFragment")
local MyFsm = require("...")

function init(self)
    local fragments = FragmentsCollection:new(self)
    fragments:addFragment(FsmFragment:new(self, MyFsm))
    self.mFragments = fragments
    fragments:init()
end
```

`FsmFragment` registers for all callbacks and forwards them to `self.fsm`. The FSM's `init(context)` receives the fragment `context`.

---

## Shared transition rules

- Returning `nil` or current state id keeps the state.
- Returning a different id triggers transition.
- `activate` may return another id to chain transitions.
- `deactivate` may return a different id to redirect the transition.
- GuiFsm additionally supports `self:goTo` for queued transitions.

## AI agent guidelines

**When to pick which:**
- Use `ScriptFsm` when a game object is fully FSM-driven.
- Use `FsmFragment` when the object has multiple fragments and one of them is FSM-based.
- Use `GuiFsm` for `.gui_script` screens and HUD state machines.

**Do:**
- Define state ids as local constants at the top of the FSM module.
- Keep state handlers focused; return next-state ids for transitions.
- Use `GuiFsm` state flags for per-state configuration.
- Forward all relevant engine callbacks from the host script.

**Don't:**
- Mix ScriptFsm and FsmFragment on the same owner unless intentional.
- Forget that `ScriptFsm` handlers receive `(vars, owner, ...)`, while `GuiFsm` handlers receive `self` as the state instance.
- Call `GuiFsm` state helpers (`:owner`, `:vars`, `:goTo`) from `ScriptFsm` states.
