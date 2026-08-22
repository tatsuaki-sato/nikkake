import { NikkakeApi, browserStore } from '@nikkake/api-client';

// 開発時はVite proxy（vite.config.ts）が'/graphql'をRailsへ転送するので相対パスのままでよいが、
// 静的サイトとしてデプロイするとproxyが無いため、本番ビルド時はAPIの絶対URLを埋め込む必要がある
const graphqlEndpoint = import.meta.env.VITE_API_ENDPOINT ?? '/graphql';

/** 画面から使う唯一のAPIインスタンス */
export const api = new NikkakeApi(browserStore(), graphqlEndpoint);

export const hexToStyle = (hex: string) => ({ backgroundColor: hex });
