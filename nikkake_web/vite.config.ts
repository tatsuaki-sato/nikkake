import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Rails を別ポートで動かし、同一オリジン扱いにする。CORS が要らなくなる。
    // （httpOnly Cookie への移行は未実装。いまはトークンを localStorage に置いている）
    proxy: {
      '/graphql': { target: 'http://localhost:3000', changeOrigin: true },
    },
  },
  build: { outDir: 'dist', sourcemap: true },
});
