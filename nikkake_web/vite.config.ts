import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Rails を別ポートで動かし、同一オリジン扱いにする。CORS が要らなくなる。
    // （httpOnly Cookie への移行は未実装。いまはトークンを localStorage に置いている）
    proxy: {
      // localhost ではなく 127.0.0.1 を指す。
      // Linux + Node 18以降は localhost が ::1 に解決されることがあり、
      // Rails が IPv4 だけで待っていると届かない
      '/graphql': {
        target: 'http://127.0.0.1:3000',
        changeOrigin: true,
      },
    },
  },
  build: { outDir: 'dist', sourcemap: true },
});
