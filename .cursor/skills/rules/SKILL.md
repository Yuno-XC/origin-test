---
name: rules
description: This is a new rule
---

# Android TV Remote App (iOS) — Master Build Specification

## Purpose
Build a **modern, premium iOS remote control app** for **Android TV / Google TV** using **pure latest SwiftUI only**.

The app must function as a **Wi-Fi remote**, supporting:
- Full remote control functionality
- Remote text typing
- Automatic TV discovery
- A polished, thumb-friendly modern UI

This is a **production-grade app**, not a demo.

---

## Target Platform
- iOS (latest supported version)
- SwiftUI only (no UIKit usage)
- Android TV as the ONLY supported TV ecosystem for v1

---

## Absolute Constraints (Do NOT violate)
- ❌ No Infrared (IR)
- ❌ No Bluetooth control
- ❌ No third-party UI frameworks
- ❌ No subscriptions in v1
- ❌ No placeholder logic
- ❌ No mixed UI + networking logic
- ❌ No multi-brand support yet

---

## Core Technical Approach
Android TV control MUST be implemented using **network-based communication over Wi-Fi**.

The app behaves as a:
- Software remote
- Network keyboard
- LAN controller

All communication is done over the local network.

---

## Architecture Rules (Non-Negotiable)

### Pattern
- MVVM only
- Protocol-driven design
- Strict separation of concerns

### Flow
SwiftUI View
→ ViewModel
→ Remote Action
→ Android TV Adapter
→ Network Command


Views must NEVER:
- Talk directly to network code
- Contain business logic
- Know Android keycodes

---

## Core Modules

### 1. App Entry & Navigation
- App launches into device discovery
- If a TV is already paired, auto-connect
- Navigation is state-driven, not button-driven

---

### 2. Device Discovery Module
Purpose:
- Discover Android TVs on the same Wi-Fi network
- Display available TVs
- Allow manual IP entry as fallback

Requirements:
- Auto scan local network
- Show TV name + connection status
- Persist known devices locally
- Gracefully handle unreachable devices

UX rules:
- Discovery must feel instant
- No blocking spinners
- Clear “Connected / Not Connected” states

---

### 3. Connection Management
Responsibilities:
- Establish Wi-Fi connection to TV
- Maintain session state
- Detect disconnects automatically

Rules:
- Connection lifecycle is centralized
- UI reacts to connection state changes
- Silent reconnection attempts allowed

---

### 4. Remote Action Abstraction
All remote behavior MUST pass through a **single action abstraction layer**.

Remote actions include:
- Directional navigation
- Selection
- System buttons (Home, Back, Menu)
- Media controls
- Volume controls
- Power toggle
- Text input

UI never sends raw commands.
UI only emits high-level actions.

---

### 5. Android TV Adapter
Purpose:
- Translate abstract remote actions into Android TV commands

Responsibilities:
- Map actions to Android TV key events
- Handle text input as sequential key events
- Manage communication reliability

Rules:
- Adapter knows Android specifics
- ViewModels do NOT
- Future TV brands must be addable without refactoring UI

---

### 6. Text Input System (Critical Feature)
This is a first-class feature, not an add-on.

Requirements:
- Full keyboard input from phone
- Real-time character transmission
- Support delete, space, enter
- Works inside TV search fields and apps

UX rules:
- Keyboard slides up naturally
- Clear “Typing on TV” state
- Haptic feedback on key send

---

### 7. Remote Control UI
The remote UI MUST:
- Be thumb-friendly
- Use modern minimal design
- Avoid clutter
- Feel fast and responsive

Required UI elements:
- Central navigation pad (tap + swipe)
- Volume controls
- Media controls
- Home / Back buttons
- Keyboard access button

Design rules:
- Dark mode first
- Large touch targets
- Haptic feedback everywhere
- Gesture support where appropriate

---

### 8. State Management
The app must clearly represent:
- Disconnected
- Connecting
- Connected
- Error states

Rules:
- No silent failures
- Errors must be human-readable
- Recovery must be obvious

---

### 9. Persistence
Persist only:
- Known TVs
- Last connected device
- User preferences

Rules:
- Local persistence only
- No cloud sync
- No analytics in v1

---

### 10. Error Handling Philosophy
Errors should:
- Never crash the app
- Never block the UI indefinitely
- Always provide a recovery path

Examples:
- TV powered off
- Network changed
- IP unreachable

---

## Development Order (Strict)
Claude must generate the app in THIS order:
1. Project structure
2. App entry & navigation
3. Device discovery
4. Connection management
5. Remote action abstraction
6. Android TV adapter
7. Remote UI
8. Keyboard input
9. Persistence
10. Polishing & edge cases

---

## Quality Bar
The final app must:
- Feel App Store ready
- Be easy to extend to other TV brands
- Be readable by another senior iOS dev
- Contain zero “TODO” logic

---

## Success Definition
The project is successful if:
- A user can control an Android TV without touching the physical remote
- Typing on TV works flawlessly
- The UI feels premium and intentional
- The architecture survives adding Samsung / LG later

---

## Claude Instructions
When generating code:
- Follow this spec strictly
- Never invent features
- Never skip layers
- Ask for confirmation only when absolutely necessary
- Prefer clarity over cleverness

