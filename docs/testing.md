# Testing changes

A short, repeatable verification list for any change — code or content.

## The 60-second smoke test

1. Open Godot, **press F5**.
2. Splash → main menu appears.
3. Hit **PLAY** — you should drop into level 1, ball spawns, depth bar
   starts at 0%.
4. Hold **Space** to test flippers. Hit a wall to test impact audio.
5. Hit a spike to test death (red flash + death sound), then click
   Retry on the results overlay.
6. Win a level (or `Esc` → Restart with a different seed) — green flash
   + win audio. Click Next Level.
7. Press **Esc** to test pause; click each pause-menu button.
8. Back in the main menu, open Level Select, Settings, Stats,
   Achievements, Ball Skins in turn — none should error.

If any of those steps fail, the change broke something. Bisect against
the last working commit.

## Headless parse check

To catch script parse errors without booting a window:

```powershell
& "C:\path\to\Godot_v4.6.2-stable_win64_console.exe" `
  --headless --path . --editor --quit
```

Watch for lines containing `ERROR` or `SCRIPT ERROR`. A clean run ends
with `loading_editor_layout` finishing and no error spam.

## Testing a single chunk

The fastest way to verify a chunk in isolation:

1. Open `resources/levels/default_level_config.tres`.
2. Temporarily set `min_chunks` and `max_chunks` to **1**.
3. Replace `chunk_pool` with just your chunk.
4. Press F5. Every level will be `start + your_chunk + finale`.
5. **Revert** the changes before committing.

## Save data

Progression persists across restarts via `user://pindown_save.json`. To
test the first-run experience, delete that file. On Windows the path
typically resolves to:

```
%APPDATA%\Godot\app_userdata\Pin Down\pindown_save.json
```

## What to verify when reorganising or renaming

If you move a file or change a class name, check that all of these
still work — they're the things most likely to break:

- The splash screen routes into the menu after its short timer.
- The main menu can launch a new run (PLAY) and the gameplay scene
  shows the procedural HUD (world, level, depth bar, timer, deaths).
- Continue routes to the last unlocked level.
- Level Select shows all five worlds with the right unlocked state.
- Pause → Restart and Pause → Menu both work.
- Ball skin equip persists across a quit/relaunch.
- Audio plays for flipper, wall, ricochet, spike, death, win.
- No `ERROR: Failed to load …` lines in the console at startup.
