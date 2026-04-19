# keyresolve setup

Wrapper + niri keybind for [KeyResolve](https://github.com/Antosser/KeyResolve),
a userspace SOCD / snap-tap cleaner (last-pressed-wins for A/D and W/S on
Linux, Wayland + X11, including games that use raw input).

## What this gives you

- **Mod+G** toggles the SOCD cleaner on/off (niri binding).
- First press on a new machine pops a `fuzzel` menu to pick which keyboard
  to grab; the choice is saved so later presses just toggle.
- Works detached — no terminal window stays open.
- Portable across machines via dotfiles: the script has no hardcoded device
  index or keyboard name.

## Files

| Path | Role | In dotfiles? |
|---|---|---|
| `~/.local/bin/keyresolve-toggle` | The wrapper script | yes |
| `~/.config/niri/config.kdl` (Mod+G binding) | Launches the wrapper | yes |
| `~/.config/keyresolve/device` | Saved keyboard name (per machine) | **no — gitignore** |
| `~/.config/keyresolve/README.md` | This file | yes |

Suggested `.gitignore` entry:

```
.config/keyresolve/device
```

## Dependencies

Installed by `install-packages.sh` (`keyresolve-git`, `fuzzel`, `libnotify`).
You must be in the `input` group (`sudo usermod -aG input $USER`, then log out).
The AUR package already installs the udev rule that gives the `input` group
access to `/dev/input/event*` and `/dev/uinput`.

## Usage

- **Toggle:** Mod+G
- **Change keyboard:** `keyresolve-toggle --reset` then press Mod+G twice
  (once to toggle off if running, once more to re-pick)
- **Manual run without the binding:** `keyresolve-toggle`

## Known gotcha: gsr-global-hotkeys

`gpu-screen-recorder-ui` spawns `gsr-global-hotkeys --all` as root, which
takes an **exclusive grab** on every keyboard to listen for hotkeys.
keyresolve can't grab a device that's already exclusively grabbed, so the
toggle will notify "SOCD on" but nothing actually happens.

If that occurs:

```
sudo pkill -f gsr-global-hotkeys
```

You lose gsr's global hotkeys until you relaunch gsr-ui. No clean workaround
unless you configure gsr-ui to listen to specific keys instead of `--all`.

## How the auto-detect works

`keyresolve` prints a numbered device list on startup and then reads an
index from stdin. The wrapper:

1. Runs `keyresolve </dev/null` to capture that list without starting it.
2. If `~/.config/keyresolve/device` has a saved name, it finds the matching
   line and extracts the index.
3. Otherwise it feeds the device names into `fuzzel` to let you pick, then
   saves the name.
4. Starts keyresolve detached via `setsid`, piping the resolved index to it.

One quirk worth knowing: gaming keyboards often expose **multiple** evdev
interfaces (e.g. a 6KRO "Keyboard" interface and a separate NKRO interface).
Only one actually emits your A/D/W/S events — the other one is silent. If
the first pick doesn't work, `--reset` and pick the other interface with
the same name.
