# HUNT Hard RP — Architecture Contract

## Decision

HUNT is a custom, server-authoritative game built **on top of** RedM and a deliberately limited VORP compatibility layer. VORP is not the owner of HUNT gameplay. It remains a proven provider for session/character compatibility and the VORP systems intentionally retained by the project.

We will not rewrite VORP or replace working systems for the sake of being "standalone". New development must use HUNT contracts; legacy direct framework use is migrated only when the touched domain is being changed or audited.

## Current snapshot (2026-08-31)

The active configuration starts `oxmysql`, `vorp_core`, selected VORP modules, and custom `thehunt_*` modules. HUNT already owns its character UX, items, grid inventory, crafting, loot, builder, doors, interactions, scenes, animations, VFX, HUD, stamina, and admin/game utilities.

The compatibility boundary is now active:

1. Direct `vorp_core` imports and dependencies have been removed from HUNT feature resources. `thehunt_core` is the sole custom-resource VORP Core adapter.
2. VORP character lifecycle events are translated once by `thehunt_core` into `thehunt:character:selected` and `thehunt:player:spawned`. New resources must subscribe only to those HUNT events.
3. `thehunt_core` starts before HUNT feature resources. Its former hard manifest dependencies on status/stamina/shapes were removed because they were operational consumers, not startup prerequisites.

This document is the target contract, not a claim that every legacy resource already follows it.

## Target layers

```text
                         RedM / Cfx natives
                                  |
              oxmysql, pma-voice, PolyZone, prompt helpers
                                  |
        VORP compatibility: core, metabolism, medic, weapons, herbs
                                  |
              thehunt_core compatibility facade
     (identity, permissions, character session, framework adapters)
                                  |
      -----------------------------------------------------------
      |                  |                   |                  |
  character          items/inventory       survival          interaction/world
      |                  |                   |                  |
  appearance       crafting / loot       status HUD      doors / builder / scenes
                                                   \
                                            presentation: menu, animations, VFX,
                                            shapes, walking, player interaction
```

`thehunt_core` is a facade, not a dumping ground. Its public contract is limited to identity/session lookup, permissions, character-ready state, common guards, and compatibility adapters. Admin tools, world cleaners, voice UI, and rendering helpers may remain there temporarily, but no new gameplay ownership belongs there.

## Ownership ledger

Every mutable fact has exactly one authoritative owner. Consumers ask its owner via a server export or consume an explicit notification; they do not write its tables, cache, or state bag themselves.

| State / capability | Authoritative owner | Readers / presentation | VORP role |
| --- | --- | --- | --- |
| Player connection, selected character ID, VORP group | `thehunt_core` facade | all domains that need identity | provider behind facade |
| Character appearance and character UI | `thehunt_character` | inventory clothing, menu, world state | current character persistence/lifecycle bridge |
| Item definitions and item mutations | `thehunt_items` | inventory, crafting, loot, builder, doors | none beyond temporary identity lookup |
| Grid layout, containers, transfer rules | `thehunt_inventory` | items and UI only | none |
| Recipes and craft queue | `thehunt_crafting` | items/inventory, interaction, status UI | none |
| World loot state and pickup authorization | `thehunt_loot` | items/inventory, interaction | none |
| Hunger and thirst | `vorp_metabolism` until explicitly replaced | `thehunt_status` is a display mirror | current authority |
| Custom stamina | `thehunt_stamina` | `thehunt_status` is a display mirror | none |
| Health, wounds and revive | `vorp_medic` plus RedM ped state until replacement | `thehunt_status` display mirror | current authority |
| Door/house lock state | `thehunt_doors` | items for key validation, interaction | identity only |
| Placed props | `thehunt_builder` | interaction/world | identity only |
| Interaction registration and G-menu | `thehunt_interact` | all world features | no gameplay ownership |
| UI focus/control lock | `thehunt_core` UI contract | every HUNT NUI resource | none |

The word **mirror** is intentional: a HUD must never independently save or change hunger, thirst, stamina, or wounds simply because it displays them.

## Public API rules

1. New custom resources must not call `vorp_core` directly. They use a narrowly defined `thehunt_core` export, for example `GetSession(source)`, `GetCharacterId(source)`, `HasPermission(source, permission)`, and character lifecycle callbacks.
2. A synchronous server-to-server business request uses an export. A domain notification uses a namespaced event such as `thehunt:inventory:itemChanged`.
3. No resource reaches into another resource's Lua locals, SQL tables, cached tables, or state bags.
4. Server events are commands, not trusted results. A client may request `thehunt:loot:pickup`; it never supplies the item it should receive, its final count, its position, or permission outcome.
5. Every public export and net event receives a short contract: inputs, output, authority, validation, failure result, and lifecycle behavior.
6. Do not use an event as a hidden request/response API when an export will do. Do not expose three aliases for one mutation: one canonical implementation and explicitly deprecated compatibility aliases only.

### Current `thehunt_core` compatibility API

Server resources use these operations instead of importing VORP:

```text
GetCharacter(source)                  compatibility character snapshot
IsSessionReady(source)                VORP user session exists; no character required
GetCharacterId(source)                active character ID
GetPlayerIdentifier(source)           character/connection identifier
GetPlayerGroup(source)                framework group through the facade
SelectCharacter(source, charId)       activate a character
CreateCharacter(source, data)         create a character
SyncCharacterCoords(source, coords)   update framework position cache
SetCharacterVitals(source, state)     update framework vital cache
UpdateCharacterAppearance(source, ...) update framework appearance cache
IsPlayerAdmin(source)                 HUNT permission decision
```

`GetCharacter` exists only to keep established field reads compatible during migration. New feature APIs should request the exact value they require (for example `GetCharacterId`) rather than depend on the framework-shaped snapshot.

## Persistence rules

- Each domain owns its own tables and migrations. Direct SQL inside that owner is normal; arbitrary cross-resource reads and writes are not.
- Schema changes are committed as ordered files in `db/migrations/`, with an ID, description, forward migration, and a safe rollback/repair note.
- Item movement, crafting completion, loot pickup, and container transfer are validated and committed by the server. Any operation that removes from one place and adds to another is transactional or uses an equivalent atomic conditional update.
- A unique constraint or conditional update protects every one-time loot, claim, and receipt operation. In-memory flags alone do not protect against reconnects, restarts, or concurrent requests.
- Database failures return a safe failure: no item is granted if the authoritative write did not succeed.

## Lifecycle contract

Every stateful resource documents and implements these paths:

```text
playerConnecting -> session available -> character selected -> character ready
character switch -> domain flush/unload -> next character ready
playerDropped -> cancel pending actions -> persist/clear owned runtime state
resource stop -> remove prompts/entities/blips/NUI focus/threads owned by resource
resource start -> rebuild only resources the module owns; never duplicate registrations
server restart -> hydrate from durable data; do not rely on old client cache
```

Resources must use unique registration IDs and remove what they create. A restart test is part of the acceptance criteria for loot, prompts, props, zones, menus, and long-running jobs.

## Startup order

The desired dependency order is below. A resource must also declare each non-optional dependency in its manifest; `server.cfg` order is not a substitute.

```text
1. Cfx/base resources, oxmysql, shared third-party utilities
2. vorp_lib -> vorp_core -> intentionally retained VORP modules
3. thehunt_shapes and thehunt_walking
4. thehunt_stamina and thehunt_status
5. thehunt_character -> thehunt_core
6. thehunt_menu -> thehunt_interact -> thehunt_worldinteractions
7. thehunt_items -> thehunt_inventory
8. thehunt_doors, thehunt_crafting, thehunt_builder, thehunt_loot, thehunt_scenes
9. thehunt_animations, thehunt_vfx, thehunt_playerinteraction and optional tools
```

Before changing the live order, audit each manifest and every actual export/event dependency. The line above is the intended graph, not permission to reorder blindly.

## Migration plan

### Phase 0 — freeze the boundary (complete)

- Add this document to every feature request and code review.
- No new direct VORP calls outside `thehunt_core` compatibility files.
- Inventory/loot/crafting and character lifecycle changes require an owner, API contract, and restart/reconnect test list before implementation.

### Phase 1 — make the current graph truthful (in progress)

- Direct `vorp_core` imports and framework lifecycle subscriptions were migrated to the facade; continue inventorying retained VORP-module events separately.
- Feature manifests now depend on `thehunt_core`; continue auditing non-framework HUNT-to-HUNT dependencies.
- Identify duplicate exports and aliases; `thehunt_items` currently contains multiple `GiveItem` export declarations and needs one canonical path before more systems depend on it.
- Tag every state as owner, mirror, or cache. The highest-risk audit order is item transfer/loot/crafting, character switching, then metabolism/health/stamina.

### Phase 2 — introduce the facade incrementally

- Put all newly needed VORP access behind `thehunt_core` server/client adapter modules.
- Migrate a single domain at a time, beginning with the next module being edited. Do not perform a broad search-and-replace.
- Keep compatibility exports only with an explicit removal target; log their use during development so remaining consumers are visible.

### Phase 3 — harden high-risk gameplay

- Make item, loot and crafting mutations server-authoritative and atomic.
- Normalize audit logs for creation, deletion, transfer, craft start/finish/cancel, loot claim, and admin action.
- Add repeatable tests for reconnect, character switch, resource restart, duplicate client events, invalid payloads, full inventory, and concurrent pickup.

### Phase 4 — replace VORP only when justified

Keep `vorp_core` while its identity/session contract serves HUNT reliably. Replace `vorp_metabolism` only when the desired survival model cannot be expressed safely as an adapter. A replacement must be a vertical slice: owner, migrations, API, migration of one consumer, live tests, then old-path removal.

## Definition of done for a new HUNT domain

- Owner and source of truth are named.
- Server API and client event contract are documented.
- Framework calls are confined to the facade.
- All client input is validated server-side.
- Persistence and concurrency rules are defined.
- Character switch, disconnect, resource restart, and server restart are handled.
- UI uses HUNT focus/control and notification standards.
- No duplicated authoritative loop or cache is introduced.
- Resource-level tests and an in-game acceptance checklist exist.

## What this means for AI-assisted work

AI is acceptable for implementation, but not as the owner of product or architecture decisions. A change request must state the owner, API boundary, persistence, authority, lifecycle, and tests. For a bug, first trace the execution path and identify the root cause; then make the smallest compatible change. A separate review pass checks dependencies, event validation, database effects, cleanup, and performance before the feature is considered ready.
