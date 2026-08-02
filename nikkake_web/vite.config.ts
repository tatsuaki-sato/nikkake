import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Rails を別ポートで動かし、同一オリジン扱いにする。
    // こうすると httpOnly Cookie がそのまま効き、CORS も要らない。
    proxy: {
      '/graphql': { target: 'http://localhost:3000', changeOrigin: true },
    },
  },
  build: { outDir: 'dist', sourcemap: true },
});
