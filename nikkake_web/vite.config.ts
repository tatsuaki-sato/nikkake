import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

// タブごとにURLを直接開けるようにする。
// このアプリはSPAで、`/routines/`のようなパスは実在するファイルではなく
// クライアント側のJSがURLを見て判断しているだけ。ホスティング先(Render の
// 静的サイト)がSPA向けのリライト設定を持たない場合、直接アクセスやリロードで
// 404になる。ホスティング側の設定に頼らず、同じindex.htmlを各パスの
// 実ファイルとして複製しておくことで、どんな静的ホスティングでも動くようにする。
const spaRoutesPlugin = (routes: string[]): Plugin => ({
  name: 'spa-routes',
  // Viteの内部プラグインがindex.htmlをbundleへ追加するのはpostステージなので、
  // それより後に実行しないとまだ存在しない
  enforce: 'post',
  generateBundle(_options, bundle) {
    const indexHtml = bundle['index.html'];
    if (!indexHtml || indexHtml.type !== 'asset') return;
    for (const route of routes) {
      this.emitFile({ type: 'asset', fileName: `${route}/index.html`, source: indexHtml.source });
    }
  },
});

export default defineConfig({
  plugins: [react(), spaRoutesPlugin(['routines', 'progress', 'settings'])],
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
