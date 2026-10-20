import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// VITE_BASE is set by the GitHub Pages workflow to "/<repository-name>/".
export default defineConfig({
  plugins: [vue()],
  base: process.env.VITE_BASE || '/',
})
