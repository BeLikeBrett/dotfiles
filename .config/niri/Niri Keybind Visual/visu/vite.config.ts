import { defineConfig } from 'vite';
import elm from 'vite-plugin-elm';
import wasm from "vite-plugin-wasm";
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  base: './',
  // preserveSymlinks lets us build through a no-spaces symlink — vite-plugin-elm
  // URL-encodes file paths and chokes on the literal " " in this project's name.
  resolve: { preserveSymlinks: true },
  plugins: [elm(), tailwindcss(), wasm()],
  build: { target: "esnext" },
  worker: {
    plugins: () => [wasm(),],
    format: "es"
  },
});
