# Automation Recipe Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use writing-plans to implement this plan task-by-task.

**Goal:** Add a final-presentation-ready automation suggestion flow for Finder, Chrome, and Notes.

**Architecture:** Keep verified shortcuts DB-first. When no official shortcut matches, ask the LLM for a Shortcuts/Automator recipe instead of a made-up shortcut, show that recipe in the menu, and let the user open the Shortcuts app.

**Tech Stack:** Swift, Cocoa menu bar app, Accessibility API, SQLite, Groq OpenAI-compatible API.

---

### Task 1: Update LLM Model And Prompt

**Files:**
- Modify: `src/LLMClient.swift`

**Steps:**
1. Change the model from `llama-3.3-70b-versatile` to `openai/gpt-oss-120b`.
2. Reword the prompt so DB misses produce a Shortcuts/Automator recipe, not an asserted official shortcut.
3. Keep output short enough for a macOS notification and menu item.

### Task 2: Add Shortcuts Launcher Flow

**Files:**
- Modify: `src/AppDelegate.swift`

**Steps:**
1. Track the latest automation suggestion.
2. Add a disabled menu line for automation status.
3. Add a clickable `Shortcuts에서 만들기` menu item.
4. Enable it only after an automation recipe exists.
5. Open the Shortcuts app when clicked.

### Task 3: Scope Shortcut DB To Presentation Apps

**Files:**
- Modify: `resources/shortcuts.json`

**Steps:**
1. Keep Finder entries.
2. Replace Safari/Preview/KakaoTalk entries with Chrome and Notes entries.
3. Include aliases for `Google Chrome`, `Chrome`, `Notes`, and `메모`.

### Task 4: Verify

**Commands:**
- Run: `./build.sh`
- Expected: `✅ Built: build/macsense`

**Manual QA:**
- Launch `build/macsense` after granting Accessibility/Input Monitoring permissions.
- Repeated official actions should show DB shortcut recommendations.
- Repeated unsupported actions should show an automation recipe and enable the Shortcuts launcher menu item.
