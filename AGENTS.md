# HUNT: Hard RP — Server Architecture & Guidelines

## 1. Custom Resources
- `thehunt_items`: Core inventory items registry, database persistence, item drops, props streaming and item usage logic.
- `thehunt_inventory`: DayZ-style grid inventory NUI (HTML/CSS/JS), drag-and-drop, splitting, proximity tracking.
- `thehunt_crafting`: Field (J) and station/workbench (G) crafting system, collapsible categories, dynamic resource calculator, craft queue and delayed resource deduction.
- `thehunt_doors`: Custom door management and lock system.
- `thehunt_status`: Status HUD, hunger, thirst, stamina, health, and central Toast Notifications system (`thehunt_status:notify`).
- `thehunt_builder`: Building and prop placement system.
- `thehunt_shapes`: Standalone 3D geometric shape rendering engine (Spheres, Cubes/Boxes, Disks, Cylinders, Axes) with clean export API.
- `thehunt_vfx`: Universal VFX/FX engine, runtime API & admin VFX studio (/vfx, F6), 3D gizmo placement, particles registry, AnimPostFX, Timecycles, lights and presets.
- `thehunt_loot`: Autonomous world loot system for post-apocalyptic dark fantasy RedM, dynamic streamer, anti-dupe authoritative server verification, 3D zone editor (/looteditor) with mouse item picker and oxmysql persistence.
- `thehunt_scenes`: 3D RP scenes note system, Raycast surface placement, MySQL persistence, and auto-cleanup.
- `thehunt_animations`: Standalone Obsidian animations & emotes system, F3 menu, F1 cancel, oxmysql persistent favorites, full/upper body modes and search.
- `thehunt_interiors`: Dynamic interior entity set manager, world states (1907 epilogue), completed buildings, unboarded shops, moonshine shacks and secret story interiors.

---

## 2. Style Guides & Systems
- **Item Icons SVG Style Guide**: See [.agents/rules/item_icon_style_guide.md](file:///c:/Users/borch/Desktop/RedM_Server/.agents/rules/item_icon_style_guide.md).
  - All inventory items use clean vector SVG icons with consistent `viewBox` (1x1: `0 0 28 28`, 1x2: `0 0 28 44`, etc.).
  - Stored in `SVG_ICONS` inside `thehunt_inventory/html/app.js`.
- **Toast Notifications System**:
  - Hosted inside `thehunt_status` (`thehunt_status:notify`, `thehunt_doors:notify` alias).
  - Types: `error` (красный `#ef4444`), `warning` (янтарный `#f59e0b`), `success` (зеленый `#22c55e`), `info` (голубой `#38bdf8`).
  - Integrated with native RedM frontend audio feedback.
- **UI Controls & Input Focus Guide**: See [.agents/rules/ui_controls_guidelines.md](file:///c:/Users/borch/Desktop/RedM_Server/.agents/rules/ui_controls_guidelines.md).
  - Total control lock during `<input>` / `<textarea>` typing focus.
  - Movement whitelist during open UI windows.
  - Placement mode control filter.
- **UI Theme & Color Palette Guide**:
  - **Obsidian Dark Palette**: `#0c0c0f` to `#15151a`, cards `#101014`, headers `#1f1f26`.
  - **Borders**: subtle `rgba(255, 255, 255, 0.09)`, medium `rgba(255, 255, 255, 0.22)`, inner `rgba(255, 255, 255, 0.08)`.
  - **Text**: Main `#ffffff`, Muted `#8f94a0`, Dim `#5a5f6d`.
  - **Функциональные акценты**: Success Green (`#22c55e`), Danger Red (`#ef4444`), Info Blue (`#38bdf8`).
  - **STRICT PROHIBITION**: NEVER use golden or bright yellow tones (`#eab308`, `#facc15`, `#d4af37`, `#c5a059`) in menus or UI elements.
- **CEF Transparency & Rendering Guidelines (Fix for Black Box Artifacts)**:
  - **NEVER use `backdrop-filter: blur(...)` or `filter: blur(...)`** on transparent windows or overlays in RedM/FiveM CEF. It causes black opaque rectangular boxes, flickering, and transparency corruption over the 3D game world.
  - `html, body` must always have `background: transparent !important; margin: 0; padding: 0; width: 100vw; height: 100vh; overflow: hidden;`.
  - Use clean alpha blending (`rgba(...)`, solid radial gradients, `box-shadow`) without CSS blur filters.
