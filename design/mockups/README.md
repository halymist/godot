# Wilds interactive UI mockup

`panel_mockups.html` is the project-owned, interactive reference for the Wilds mobile UI. It contains 22 click-through screens, inline SVG icons, embedded imagery and fonts, and JavaScript interactions. It is deliberately self-contained so it can be reviewed without the original artifact service.

## Open it

Opening the file directly in a browser works. A local server is more predictable for browser security and development tools:

```bash
cd godot
python3 -m http.server 4173 --directory design/mockups
```

Then visit <http://localhost:4173/panel_mockups.html>.

The tabs across the top are review shortcuts. Most screens also support in-phone navigation and interactions: the dock, avatar, utility rooms, quest dialogue, expedition nodes, inventory drag/drop, combat playback, settings, payment choices, and arena carousel.

## Source and ownership

- Imported from `../design_audit/panel_mockups.html` at repository-workspace level on 2026-07-24.
- The imported artifact identified itself as `Wilds — Click-through UI Demo · v5`.
- The source was copied byte-for-byte, then only a standard HTML document shell, UTF-8 declaration, viewport metadata, and description were added.
- This copy is now the canonical project reference. Make future design changes here.
- The original `design_audit` copy remains untouched as provenance and rollback material.
- `.gdignore` prevents Godot from importing the embedded multi-megabyte design file. It does not prevent Git or Codex from reading it.

## What this is (and is not)

This is a behavioral and visual target, not runtime game code. HTML pixels should not be translated mechanically into Godot. Reuse the project's existing scenes, theme resources, data flow, and overlay lifecycle. See `CODEX_HANDOFF.md` before implementing a screen.

The mockup uses a 390 × 800 phone frame. The Godot project currently targets a 405 × 900 portrait viewport, so implementations should use anchors and containers and be checked at both proportions rather than hardcoding the HTML coordinates.

## Maintenance

Keep the file self-contained. If it becomes too awkward to edit, split a development copy into CSS/JS/assets and provide a build step that regenerates this single-file review artifact. Do not add generated files to runtime asset folders.
