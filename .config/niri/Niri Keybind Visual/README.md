# Niri Keybind Visual

A native-feeling desktop launcher for [Visu](https://github.com/omer-biz/visu) (a
Niri keymap visualizer) that auto-loads your live `~/.config/niri/config.kdl`
when you press **Mod+K**, plus a per-binding notes feature so you can annotate
what each keybind does and have those notes persist between launches.

Visu upstream is a web app — this project clones it, patches it to accept an
injected config string at startup, adds a notes textarea to each binding, and
wraps everything in a tiny Python launcher that serves the built bundle
locally and opens it in a chromeless Chrome window.

---

## What gets opened when you press Mod+K

1. **Niri** reads its config and sees `Mod+K { spawn "/home/brett/Niri Keybind Visual/launcher"; }` — see `~/.config/niri/config.kdl`.
2. **Niri spawns the launcher** (`./launcher`, a Python script).
3. **The launcher**:
   - Reads `~/.config/niri/config.kdl` (your live config)
   - Reads `./notes.json` (your saved per-binding notes — empty `{}` if missing)
   - Reads `./visu/dist/index.html` (the built Visu HTML, which contains a placeholder `<script>` tag)
   - Substitutes the placeholder with `window.__NIRI_CONFIG__ = "..."; window.__NIRI_NOTES__ = {...};` and writes the result to `./visu/dist/index.runtime.html`
   - Picks a free localhost port and starts a Python `http.server` rooted at `./visu/dist/` — the server also handles `POST /api/notes` to persist notes back to `notes.json`
   - Launches `google-chrome-stable --app=http://127.0.0.1:<port>/index.runtime.html` using an isolated profile in `./chrome-profile/`
4. **Chrome loads** the runtime HTML. The inline placeholder script runs first and sets `window.__NIRI_CONFIG__` and `window.__NIRI_NOTES__`. Then the bundled Elm app loads, reads them as startup flags, and immediately parses the config via the WASM worker — so the keyboard view shows up populated, no upload step.
5. **When you type in a note**, the Elm app calls a `saveNotes` port. JS debounces the saves (~400ms idle) and POSTs the full notes dict to `/api/notes`, which the Python server writes to `notes.json`.
6. **When you close the Chrome window**, the launcher's blocking `subprocess.run` returns, the HTTP server is shut down, and the launcher exits.

Each launch re-reads `config.kdl` from disk, so edits to your niri config show up on the next Mod+K press with no caching.

---

## Folder structure

```
~/Niri Keybind Visual/
├── README.md            # this file
├── launcher             # Python launcher script (see below)
├── notes.json           # your saved per-binding notes (created on first save)
├── visu/                # cloned + patched upstream Visu repo
│   ├── src/             # Elm + TypeScript source (patched)
│   ├── parser/          # Rust → WASM parser
│   ├── dist/            # built bundle (output of `pnpm vite build`)
│   │   ├── index.html             # built HTML with placeholder
│   │   ├── index.runtime.html     # generated fresh on every launch
│   │   └── assets/                # bundled JS / CSS / WASM
│   └── ...              # rest of upstream
└── chrome-profile/      # isolated Chrome profile (cookies, cache, etc.)
```

`notes.json` is keyed by a stable per-binding ID: `<key>|<modifiers sorted>|<actions joined>`.
For example a `Mod+K` binding for `spawn "visu"` is stored as `k|MOD|spawn "visu"`.
The file is human-readable JSON — you can edit it by hand if you want.

Other paths involved that **must stay where they are**:

| Path | Why it can't move |
|------|-------------------|
| `~/.config/niri/config.kdl` | Niri reads from this hardcoded location. The launcher reads it as input. |
| `~/.local/bin/visu` | Symlink → `./launcher`. Lets you type `visu` in any terminal. Optional but handy. |

---

## The patches applied to upstream Visu

Modifications to make Visu accept an injected config + notes at startup and
emit note-edits via a port. If you ever pull upstream changes, these may need
to be reapplied.

### 1. `visu/src/Ports.elm` — outbound `saveNotes` port

```elm
port module Ports exposing (receiveParsed, saveNotes, sendConfig)

import Json.Decode as Decode
import Json.Encode as Encode

port sendConfig : String -> Cmd msg
port receiveParsed : (Decode.Value -> msg) -> Sub msg
port saveNotes : Encode.Value -> Cmd msg
```

### 2. `visu/src/Main.elm` — Flags record, notes Dict, UpdateNote msg, textarea

Key additions:

- `Model` gains a `notes : Dict String String` field
- `Flags` is now a record `{ config : Maybe String, notes : Decode.Value }`
- `Msg` has a new `UpdateNote String String` variant
- `bindingId : Binding -> String` builds a stable ID from key + sorted modifiers + actions
- `viewBindingDetail` now takes the notes dict and renders a `<textarea>` per binding wired to `UpdateNote bid`
- The update handler for `UpdateNote` updates the model and emits `Ports.saveNotes (encodeNotes newNotes)`

### 3. `visu/src/main.ts` — pass flags, subscribe to saveNotes

```ts
const w = window as unknown as {
  __NIRI_CONFIG__?: string;
  __NIRI_NOTES__?: Record<string, string>;
};

const app = Elm.Main.init({
  node: document.getElementById("app"),
  flags: {
    config: w.__NIRI_CONFIG__ ?? null,
    notes: w.__NIRI_NOTES__ ?? {}
  }
});

// Debounced persistence
let saveTimer: number | undefined;
app.ports.saveNotes.subscribe((notes: Record<string, string>) => {
  if (saveTimer !== undefined) window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    fetch("/api/notes", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(notes)
    }).catch((err) => console.error("visu: failed to save notes:", err));
  }, 400);
});
```

### 4. `visu/index.html` — placeholder script the launcher substitutes into

```html
<div id="app" class="flex-1 flex flex-col min-h-0"></div>
<script>/*__NIRI_CONFIG_PLACEHOLDER__*/</script>
<script type="module" src="/src/main.ts"></script>
```

### 5. `visu/vite.config.ts` — relative asset paths

```ts
export default defineConfig({
  base: './',
  resolve: { preserveSymlinks: true },
  // ...
});
```

Without `base: './'`, the built HTML references `/assets/...` (absolute), which
breaks once it's served from a subdirectory or opened from a non-root URL.

### 6. `node_modules/.../vite-plugin-elm/dist/index.js` — URL-decode bug fix

Because this project's directory has spaces in its name, vite-plugin-elm 3.0.1
chokes on the path: it does `new URL(id, 'file://').pathname` which URL-encodes
spaces to `%20`, then passes that literal string to the Elm compiler as a file
path. Patch in `parseImportId`:

```js
const pathname = decodeURIComponent(parsedId.pathname);
```

**This patch lives in `node_modules/` and will be lost if you run `pnpm install`.**
Reapply it manually, or set up a `pnpm patch` for it. Upstream bug — worth
filing if it's not fixed yet.

---

## Rebuilding after pulling upstream changes

```bash
cd ~/Niri\ Keybind\ Visual/visu
git pull
# reapply the patches above if upstream touched Main.elm/main.ts/index.html/vite.config.ts/Ports.elm
(cd parser && wasm-pack build --target web --out-dir pkg)
pnpm install   # only if package.json changed — and if you do this, REAPPLY patch #6
pnpm vite build
```

The launcher reads from `dist/index.html`, so as long as the build succeeds and
the placeholder survived, the next Mod+K press will pick up the rebuild.

---

## Build prerequisites (already installed)

- `rustup` + `wasm32-unknown-unknown` target (pacman)
- `wasm-pack` (pacman)
- `nodejs`, `pnpm` (pacman)
- `elm-bin` (AUR — note: NOT `elm`, which is a 1980s email client)
- `google-chrome-stable` (already installed)

---

## Changing the keybind

Edit `~/.config/niri/config.kdl` and change the line:

```kdl
Mod+K { spawn "/home/brett/Niri Keybind Visual/launcher"; }
```

Niri auto-reloads on save, so no restart needed. You can verify the config is
valid with:

```bash
niri validate --config ~/.config/niri/config.kdl
```

The previous binding on `Super+K` (Noctalia's `keybind-cheatsheet` plugin
toggle) was removed when this was set up.

---

## Notes feature

When you click any key on the keyboard view, each binding card in the right
panel has a **NOTE** textarea below the actions list. Type whatever you want —
the Elm app emits a `saveNotes` port message on every keystroke, JS debounces
saves to one POST per ~400ms idle, and the launcher's HTTP server writes the
full notes dict back to `~/Niri Keybind Visual/notes.json`. Clearing the
textarea removes the note from the file.

Notes are keyed by a stable per-binding ID (`key|sorted-modifiers|actions`), so:

- Editing your niri config to add comments / reorder bindings → notes stick
- Renaming a key or changing the action of a binding → its note disappears
- Two different bindings on the same key (different modifier combos) get
  independent notes
- You can hand-edit `notes.json` if you want — it's pretty-printed with sorted
  keys

---

## Common issues

**Visu opens but only the header renders, no keyboard / no upload area**
The Elm app failed to mount. Most common cause: Chrome is loading from
`file://` instead of `http://127.0.0.1:...` and is blocking the ESM bundle.
Make sure the launcher is the up-to-date HTTP-server version (not an older
file:// version). Second most likely cause: you ran `pnpm install` and lost
the vite-plugin-elm patch (#6) — Elm fails to compile, but the launcher
serves the stale `dist/` and Chrome shows whatever the last good build had.

**Notes don't persist after closing Visu**
Check that `~/Niri Keybind Visual/notes.json` is being written. Open
DevTools (Ctrl+Shift+I) in the Visu window, type a note, and watch the
Network tab for a `POST /api/notes` returning 204. If it 404s, the launcher
is running an older version without the API endpoint — restart it. If the
file isn't written, check filesystem permissions.

**`pnpm vite build` fails with `ENOENT: no such file or directory, open '...%20...'`**
The vite-plugin-elm patch (#6) was lost. Reapply it — see the patches
section above.

**`visu: build not found at .../dist/index.html`**
Run `pnpm vite build` in `./visu/` to produce `dist/`.

**`visu: placeholder ... not found in built index.html`**
The placeholder `<script>/*__NIRI_CONFIG_PLACEHOLDER__*/</script>` is missing
from `visu/index.html`. Reapply patch #3 above and rebuild.

**Mod+K does nothing**
Check that `~/.config/niri/config.kdl` actually contains the `Mod+K { spawn ... }`
line and that the path matches the launcher location. `niri validate` will
catch syntax errors.

**Chrome complains about an existing instance**
The launcher uses an isolated `--user-data-dir=./chrome-profile`, so it should
never collide with your normal Chrome session. If it does, there's a stale
`SingletonLock` in `./chrome-profile/` — delete it.

---

## Uninstalling

```bash
rm -rf ~/Niri\ Keybind\ Visual
rm ~/.local/bin/visu
# then manually remove the Mod+K line from ~/.config/niri/config.kdl
```

That removes everything project-related. The pacman/AUR build dependencies
(`rustup`, `wasm-pack`, `nodejs`, `pnpm`, `elm-bin`) stay installed unless you
remove them separately.
