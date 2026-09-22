# HUNT: Hard RP — AI Notes & Architectural Directives

## 1. UI Design & Style Guide
- **Theme**: Obsidian Dark / Steel Gray / Hunter Amber.
- **Backgrounds**:
  - Main Window: `radial-gradient(circle at center, #15151a 0%, #0c0c0f 100%)`
  - Sidebar: `#0d0d10`
  - Headers / Topbars: `linear-gradient(180deg, #1f1f26 0%, #121216 100%)`
  - Cards: `#101014`
  - Inputs: `rgba(0, 0, 0, 0.55)`
- **Borders**:
  - Subtle: `rgba(255, 255, 255, 0.09)`
  - Medium / Active: `rgba(255, 255, 255, 0.22)`
  - Inner Double Border: `rgba(255, 255, 255, 0.08)`
- **Typography**:
  - Font: `'Inter', 'Segoe UI', 'Roboto', Arial, sans-serif !important; font-weight: 600;`
  - Main: `#ffffff`
  - Muted: `#8f94a0`
  - Dim: `#5a5f6d`
  - Success / Save: `#22c55e` (`rgba(34, 197, 94, ...)`)
  - Danger / Delete: `#ef4444` (`rgba(239, 68, 68, ...)`)
  - Info / Secondary: `#38bdf8` (`rgba(56, 189, 248, ...)`)
- **STRICT PROHIBITION**:
  - **NO GOLD OR YELLOW** (`#eab308`, `#facc15`, `#d4af37`, `#c5a059`). Do not use gold in any buttons, headers, borders, or icons.

---

## 2. CEF Transparency & Rendering Bug Fix (RedM / FiveM)
- **Problem**: In Chromium Embedded Framework (CEF), using CSS `backdrop-filter: blur(...)` or `filter: blur(...)` on semi-transparent elements rendered on top of the 3D game world creates solid black/gray artifact boxes, visual tearing, and transparency breakage.
- **Rules**:
  1. **NEVER use `backdrop-filter: blur(...)` or `filter: blur(...)` in any NUI CSS.**
  2. `html, body` must always be declared as:
     ```css
     html, body {
       background: transparent !important;
       overflow: hidden;
       width: 100vw;
       height: 100vh;
       margin: 0;
       padding: 0;
     }
     ```
  3. Window depth must be achieved through radial/linear gradients, clean alpha blending (`rgba(...)`), solid dark backgrounds, and subtle `box-shadow` instead of CSS blurs.

---

## 3. UI Controls & Focus Management
- When `<input>` or `<textarea>` has focus: **TOTAL game control lock** (`DisableAllControlActions(pad)` on pads 0, 1, 2).
- When a UI window is open without text focus: Whitelist movement, sprint, jump, duck, and push-to-talk (`DisablePlayerFiring(ped, true)`).
