# ChatEase

ChatEase is a World of Warcraft Retail addon for fast chat routing and template sending.

This project targets Retail API `12.0.1` and uses an original implementation.

## What It Does

- Persistent quick chat bar with preset channels plus all enabled templates
- Preset channel buttons that prefill the chat edit box instead of sending immediately
- Text templates that send through a configured route
- Slash templates that execute commands directly (for example `/pull`, `/ready`, `/roll`)
- Config panel with two sections:
  - `General` for quick bar options and permission feedback
  - `About` for addon intro, version, notes, and usage tips
- Template manager with search, create/edit/delete, reorder, and per-character overrides
- Quick bar appearance controls for text/icon mode, icon color set, background, lock state, and scale
- Account-wide templates with per-character overrides
- Multi-language scaffolding (11 locale files)

## Install

1. Copy this folder as:
   - `World of Warcraft/_retail_/Interface/AddOns/ChatEase`
2. Ensure the folder contains `ChatEase.toc`.
3. Restart the game or run `/reload`.

## Everyday Use

- `/ce` or `/ce config` opens the config panel.
- The quick bar is enabled by default and anchors near `ChatFrame1`.
- Right-click the quick bar to toggle its locked state.
- Preset channel buttons only prime the edit box; they do not send text by themselves.
- Enabled templates are appended after the preset channels on the quick bar.

## Slash Commands

- `/ce` - Toggle config panel
- `/ce config` - Toggle config panel
- `/ce panel` - Alias of `/ce config`
- `/ce send <templateId>` - Execute a template
- `/ce channel <alias> <message>` - Send through a channel alias
- `/ce channel w <message>` - Reply to the last whisper target
- `/ce channel whisper <target> <message>` - Send a targeted whisper
- `/ce bar` - Toggle quick chat bar visibility
- `/ce bar [lock|unlock|togglelock|show|hide]` - Quick chat bar control
- `/ce bar style text|icon` - Set quick chat bar style
- `/ce bar togglestyle` - Toggle text/icon style
- `/ce bar iconset color|class|mono` - Set icon color scheme
- `/ce bar toggleiconset` - Cycle icon color schemes
- `/ce bar bg [on|off|toggle]` - Control quick chat bar background
- `/ce bar togglebg` - Toggle quick chat bar background
- `/ce help` - Print help

## Channel Aliases

- `world` / `1`
- `s` / `say`
- `y` / `yell`
- `p` / `party`
- `i` / `instance`
- `raid` / `r`
- `g` / `guild`
- `o` / `officer`
- `rw`
- `w` - Reply to the last whisper target (`/r`)
- `whisper` - Targeted whisper helper (`<target> <message>`)
- `e` / `emote`

## Templates

- Text templates send through their configured default channel.
- Slash templates execute their content directly and ignore channel-specific routing.
- Built-in templates: `pull`, `ready`, `summon`, `buff`, `roll`.
- Per-character overrides can change enabled state, default channel, and sort order.

## Saved Variables

- `ChatEaseDB` (account-wide)
- `ChatEaseCharDB` (per-character overrides)
