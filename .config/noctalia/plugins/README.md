# Brett's custom Noctalia plugins

Plugins in this directory are either **original work** or **forks** of upstream
Noctalia plugins with local modifications. Noctalia has no plugin auto-updater,
so keep an eye on them over time — run the `/noctalia` Claude skill to check
for drift against upstream or Noctalia shell API changes.

## Custom plugins

### `brettlot-tasks/`
Bar widget + panel that syncs with Brett's self-hosted BrettLoT Go API. Lets
Brett see and complete ADHD todo-list items from the Noctalia bar without
opening the Android app. Original plugin, no upstream.

### `gsr-noctalia/`
Fork of the upstream `screen-recorder` plugin (gpu-screen-recorder frontend).
Main additions over upstream:

- **Multi-track audio** — GSR-style per-track Output + Input slots so you can
  record desktop audio and mic as separate streams, editable independently in
  post. Per-track "Custom expression…" mode for advanced sources (`app:firefox`,
  `app-inverse:discord`, etc.).
- **24/7 replay buffer** — toggle that auto-starts the replay buffer on shell
  load, keeps it rolling after each `saveReplay`, and restarts it if the GSR
  process dies. Accessible from the bar-widget right-click menu and settings.
- **Extra encoder knobs** — container (mp4/mkv/flv/webm), audio bitrate,
  bitrate mode (auto/qp/vbr/cbr), framerate mode (vfr/cfr/content), GPU/CPU
  encoder with CPU fallback, keyframe interval, post-save script, 10-bit codec
  variants, date-based replay folders.

## Other plugins

Everything else in this directory is an **unmodified** upstream plugin from
<https://github.com/noctalia-dev/noctalia-plugins>. They update via Noctalia's
plugin manager and don't need special attention.
