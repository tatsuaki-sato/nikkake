/**
 * データの取得元。
 *
 * local  : 端末のストレージが真実の源。ネットワークを一切使わない（移行前の挙動）
 * server : Rails の GraphQL が真実の源。集計もサーバが返す
 *
 * 移行中は両方を残し、同じ E2E スイートが両方で通ることを
 * 「挙動が変わっていない」ことの証明にしている。
 * server 側が安定したら local を落とす。
 */
export type BackendMode = 'local' | 'server';

export const BACKEND: BackendMode =
  (process.env.EXPO_PUBLIC_BACKEND as BackendMode | undefined) ?? 'local';

/**
 * 既定は 127.0.0.1。localhost にしないのは、Linux + Node 18以降だと
 * ::1 に解決されることがあり、IPv4 だけで待っている Rails に届かないため。
 * 実機やエミュレータから見るときは EXPO_PUBLIC_API_ENDPOINT で上書きする。
 */
export const API_ENDPOINT: string =
  process.env.EXPO_PUBLIC_API_ENDPOINT ?? 'http://127.0.0.1:3000/graphql';

export const isServerBackend = () => BACKEND === 'server';
