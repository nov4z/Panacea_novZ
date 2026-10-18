# Project: panacea-antigravity-notch

## Architecture
Panacea is a Quickshell-based dynamic notch / status bar for Wayland/Hyprland.
This project integrates an animated, real-time Antigravity activity indicator into the Panacea notch:
1. **Activity & Subagent Detection Engine**: A lightweight Python daemon (`scripts/watch_antigravity.py`) monitors `/home/nova/.gemini/antigravity/conversations/` for non-empty SQLite WAL files and active step statuses in `steps` table (`1, 2, 8, 11`), distinguishing subagents via `trajectory_metadata_blob` (`parent_conversation_id`). Streams state JSON lines via stdout to Quickshell.
2. **Quickshell Integration & State**: `shell.qml` runs `watch_antigravity.py` via `Process` + `SplitParser`, maintaining reactive properties:
   - `antigravityActive`: bool (true when tasks are executing)
   - `antigravitySubagents`: int (count of active subagents)
   - `antigravityEnabled`: bool (toggled via Super + O, default true, persisted in `settings.json`)
   - `effectiveAntigravityVisible`: `antigravityActive && antigravityEnabled`
3. **Visual Components**:
   - `AntigravityLogo.qml`: Authentic transparent multi-colored Antigravity logo (`assets/antigravity.png`) with smooth, fluid, infinite levitation animation (60fps GPU-accelerated sinusoidal translate/scale/rotate).
   - `AntigravityWave.qml`: Calm progress wave ("ola tranquila") rendered via `Canvas` (dual-harmonic continuous sine ribbon with boundary taper) oscillating in the notch accent color (`effectiveWaveColor` during media, `colOn` during idle), accompanied immediately to its right by the subagent counter badge (hidden when subagents == 1, visible when subagents >= 2).
4. **Adaptive Notch Layout**:
   - When media is playing (`musicCapsule`):
     - `AntigravityLogo` anchored immediately to the right of `FlipArt` (`anchors.left: musicArtBox.right; anchors.leftMargin: 8`).
     - `AntigravityWave` anchored immediately to the left of `WaveBars` (`anchors.right: musicWave.left; anchors.rightMargin: 10`).
     - `musicCapsule.implicitWidth` expands to accommodate indicators without center collisions.
   - When no media is playing (`modernCapsule` / `idleCapsule`):
     - `AntigravityLogo` placed at far left of notch (first item in `modernRow`).
     - `AntigravityWave` placed at far right of notch (last item in `modernRow`).
     - Automatic expansion via `RowLayout.implicitWidth`.
5. **Keybindings & IPC**:
   - `Super + O` bound in `~/.config/hypr/lua/keybindings.lua` executing `qs -c ~/.config/panacea ipc call pill toggleAntigravity`.
   - `IpcHandler { target: "pill" }` toggles `root.antigravityEnabled` and saves to `settings.json`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Detection Engine Daemon | Lightweight Python daemon detecting active Antigravity tasks via SQLite WAL & step status | M1 | ORIGINAL_REQUEST §R3 |
| F2 | Subagent Counter Detection | Accurate detection of running subagents via trajectory metadata hierarchy | M1 | ORIGINAL_REQUEST §R3 |
| F3 | Quickshell Process Bridge | Real-time JSON line streaming from daemon to QML properties via Process + SplitParser | M1 | ORIGINAL_REQUEST §R3 |
| F4 | Authentic Logo Asset & Rendering | Multi-colored Antigravity logo without background, rendered cleanly in QML | M2 | ORIGINAL_REQUEST §R1 |
| F5 | Fluid Infinite Animation | 60fps smooth, fluid, infinite levitation animation for Antigravity logo | M2 | ORIGINAL_REQUEST §R1 |
| F6 | Calm Progress Wave ("Ola Tranquila") | Continuous gentle sine wave oscillating vertically in notch accent color | M2 | ORIGINAL_REQUEST §R2 |
| F7 | Notch Accent Color Matching | Wave color matching music visualizer / album glow (`effectiveWaveColor`) during media, theme accent (`colOn`) during idle | M2 | ORIGINAL_REQUEST §R2 |
| F8 | Subagent Counter Display | Number right of wave: hidden when 1 subagent active, shown when >= 2 subagents active | M2 | ORIGINAL_REQUEST §R2 |
| F9 | Smooth Idle / Active Transitions | Indicator smoothly appears when active and disappears when Antigravity is idle | M2 | ORIGINAL_REQUEST §R2 |
| F10 | Media Layout Placement | Logo right of cover art; wave left of equalizer bars during media playback | M3 | ORIGINAL_REQUEST §R1, §R2 |
| F11 | Idle Layout Placement | Logo far left of notch; wave far right of notch when no media is playing | M3 | ORIGINAL_REQUEST §R1, §R2 |
| F12 | Super + O Shortcut Toggle | Keybinding Super + O toggles visibility on/off immediately, default enabled | M3 | ORIGINAL_REQUEST §R1 |
| F13 | Settings Persistence & IPC | Quickshell IPC handler toggles state and persists to settings.json | M3 | ORIGINAL_REQUEST §R1 |
| F14 | Comprehensive E2E Test Suite | Automated test suite verifying detection, state transitions, IPC, and layouts | M4 | ORIGINAL_REQUEST §Acceptance Criteria |
| F15 | Live Visual Quality & Screenshot Verification | Live screenshots verifying layout, proportions, and animations with and without media | M4 | ORIGINAL_REQUEST §R4 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Activity & Subagent Detection Engine | `scripts/watch_antigravity.py`, WAL scanning, SQLite status queries, JSON stdout, Quickshell Process integration test | none | DONE |
| M2 | Logo Asset & QML Visual Components | `assets/antigravity.png`, `AntigravityLogo.qml`, `AntigravityWave.qml`, animation timers/curves, accent color binding | M1 | DONE |
| M3 | Notch Layout & Super + O Integration | `shell.qml` layout wiring (`musicCapsule` & `modernCapsule`), IPC handler, `settings.json`, `keybindings.lua` | M1, M2 | DONE |
| M4 | E2E Testing Suite Pass & Visual Verification | Validate 100% E2E test pass (Tiers 1-4), Tier 5 adversarial tests, capture live screenshots with/without media | M1, M2, M3 | PLANNED |

## Interface Contracts
### Detection Engine Daemon ↔ Quickshell QML
- Command: `python3 ~/.config/panacea/scripts/watch_antigravity.py`
- Protocol: Newline-delimited JSON strings to stdout
- Schema:
  ```json
  {
    "active": true,
    "subagents": 2,
    "total": 3
  }
  ```
- Latency: <= 150ms state transition delay
- CPU Overhead: <= 0.05% CPU

### Quickshell IPC ↔ Hyprland Keybinding
- Target: `pill`
- Method: `toggleAntigravity()`
- CLI Invocation: `qs -c /home/nova/.config/panacea ipc call pill toggleAntigravity`
- Effect: Flips `root.antigravityEnabled` and saves to `~/.config/panacea/settings.json` (`"antigravityEnabled": true/false`)

### Component Contracts
- `AntigravityLogo.qml`:
  - `property bool active`: drives entrance/exit opacity & scale
  - `property int size`: 18-20 px
- `AntigravityWave.qml`:
  - `property bool active`: drives visibility
  - `property color waveColor`: bound to `root.effectiveWaveColor` (media) / `root.colOn` (idle)
  - `property int subagentCount`: active subagent count
  - `property color textColor`: text color for counter badge

## Code Layout
- `scripts/watch_antigravity.py`: Real-time activity and subagent detection daemon
- `assets/antigravity.png`: Authentic transparent multi-colored Antigravity logo
- `AntigravityLogo.qml`: Animated Antigravity logo component
- `AntigravityWave.qml`: Calm progress wave and subagent counter component
- `shell.qml`: Panacea notch container, layouts, IPC handler, and Process bridge
- `settings.json`: Configuration settings with `antigravityEnabled`
- `tests/`: E2E test harness and test suites
