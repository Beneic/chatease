# ChatEase Design Snapshot (2026-04-20)

## 1. Product Goal
ChatEase is a World of Warcraft Retail addon (`12.0.1`) focused on fast chat routing and template execution.

Current product goals:
- Keep common chat routes available from a persistent quick bar.
- Let templates and slash-command templates share one management surface.
- Keep template data account-wide while allowing per-character overrides.
- Preserve localized UI coverage across the existing locale set.

## 2. Current User Surface

The shipped addon currently exposes two primary UI surfaces:

- `UI/ChatBar.lua`
  - Persistent quick bar anchored near `ChatFrame1` by default.
  - Contains preset channel buttons followed by all enabled templates.
  - Preset channel buttons prefill the chat edit box with the proper slash route.
  - Template buttons execute immediately.
- `UI/ConfigPanel.lua`
  - Main configuration and template management panel.
  - Left-side tab switch between `General` and `About`.
  - Middle column for searchable preset/template list.
  - Right column for template editing.

There is no shipped send-mode toggle in the current build. The old `direct` / `editbox` split has been removed.

## 3. Shipped Architecture

Runtime files loaded by `ChatEase.toc`:

- `Core/Compat.lua`
- `Core/Theme.lua`
- `DB/Defaults.lua`
- `Modules/Permission.lua`
- `Modules/TemplateStore.lua`
- `Modules/CommandRouter.lua`
- `UI/ChatBar.lua`
- `UI/ConfigPanel.lua`
- `Core/Init.lua`

Responsibilities:
- `Core/Init.lua`: addon bootstrap, saved-variable init, migrations, slash registration, module init.
- `Core/Compat.lua`: retail-safe wrappers, helpers, default merging, deferred protected work.
- `Core/Theme.lua`: shared visual styling and color access.
- `DB/Defaults.lua`: schema version, quick bar defaults, built-in templates.
- `Modules/Permission.lua`: raid-warning permission checks and user feedback.
- `Modules/TemplateStore.lua`: template CRUD, ordering, account/character merge behavior.
- `Modules/CommandRouter.lua`: alias resolution, chat routing, slash-template execution, slash handler.
- `UI/ChatBar.lua`: compact execution surface for channel priming and template buttons.
- `UI/ConfigPanel.lua`: settings, about view, preset route list, template editing, reorder controls.

Repository note:
- `UI/MainPanel.lua` still exists in the repo, but it is not loaded by `ChatEase.toc` and is not part of the current shipped UI.

## 4. Command Model

Slash entry points:
- `/ce`, `/ce config`, `/ce panel` -> toggle config panel.
- `/ce send <templateId>` -> execute a template.
- `/ce channel <alias> <message>` -> send through a resolved route.
- `/ce channel w <message>` -> reply to the last whisper target.
- `/ce channel whisper <target> <message>` -> targeted whisper helper.
- `/ce bar ...` -> quick bar visibility and appearance control.

Current alias map:
- `world`, `1`
- `s`, `say`
- `p`, `party`
- `i`, `instance`
- `raid`, `r`
- `rw`
- `g`, `guild`
- `o`, `officer`
- `y`, `yell`
- `e`, `emote`
- `w` (reply route via `/r`)
- `whisper` (explicit target required)

Execution rules:
- Preset channel buttons always prefill the edit box; they do not send a message immediately.
- Text templates call the unified chat send path.
- Slash templates execute their slash content directly.
- Permission-gated routes fail safely and print localized feedback.

## 5. Template Data Model

Saved variables:
- `ChatEaseDB` (account scope)
- `ChatEaseCharDB` (character scope)

Merge precedence:
- Character override
- Account template
- Defaults

Core template fields:
- `id`
- `nameKey` or `displayName`
- `content`
- `defaultChannel`
- `kind` (`text` implicit, `slash` explicit)
- `enabled`
- `requirePermission`
- `tags`

Character override fields currently exposed in UI:
- `enabled`
- `defaultChannel`
- `order`

## 6. UI Details

### 6.1 Quick Bar
- Defaults to `text` style.
- Supports `text` and `icon` display modes.
- Supports `color`, `class`, and `mono` icon color sets.
- Supports background on/off, lock state, visibility toggle, and scale.
- Right-click toggles lock.

### 6.2 Config Panel
- `General` tab:
  - permission feedback toggle
  - quick bar lock toggle
  - quick bar background toggle
  - quick bar scale slider
- `About` tab:
  - addon title
  - version and notes
  - localized highlights
  - quick usage summary

### 6.3 Template Manager
- Preset channel entries are shown as read-only items at the top of the list.
- Search matches preset entries and templates.
- Template rows use compact labels for the list and aligned short labels for the quick bar.
- Reorder buttons operate on the visible order and preserve per-character ordering overrides when needed.

## 7. Built-In Defaults

Current built-in templates:
- `pull` -> slash template `/pull`
- `ready` -> slash template `/ready`
- `summon` -> text template
- `buff` -> text template
- `roll` -> slash template `/roll`

Quick bar defaults:
- enabled
- anchored relative to `ChatFrame1`
- background off
- scale `1`
- preferred alias `s`

## 8. Internationalization

Shipped locale set:
- `enUS`, `zhCN`, `zhTW`, `koKR`, `deDE`, `frFR`, `esES`, `esMX`, `itIT`, `ptBR`, `ruRU`

Rules:
- `enUS` remains the baseline table.
- Other locales override incrementally.
- Fallback remains `current locale -> enUS -> raw key`.

Coverage includes:
- chat bar labels
- config panel labels
- about-page content
- command help text
- validation and error messages

## 9. Compliance and Safety

- Target WoW Retail `12.0.1`.
- Use retail-safe APIs only.
- Centralize sends in `Modules/CommandRouter.lua`.
- Keep permission checks explicit for raid-warning actions.
- Defer protected UI mutations through compat helpers when required.

## 10. Acceptance Criteria

1. Addon loads on Retail `12.0.1` without Lua errors.
2. `/ce`, `/ce config`, `/ce send`, `/ce channel`, and `/ce bar` behave as documented.
3. Quick bar appearance settings persist across reloads.
4. Preset channel entries stay read-only in the config panel.
5. Template account/character merge precedence remains correct.
6. Locale fallback remains non-fatal.

