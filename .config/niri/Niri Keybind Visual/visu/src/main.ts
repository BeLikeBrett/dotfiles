import './style.css'
import { Elm } from "./Main.elm";

const worker = new Worker(
  new URL("./parser.worker.ts", import.meta.url),
  { type: "module" }
);

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

app.ports.sendConfig.subscribe((configStr: string) => worker.postMessage(configStr));
worker.onmessage = (e) => app.ports.receiveParsed.send(e.data);

// Debounced persistence: keystrokes coalesce into one POST per ~400ms idle.
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
