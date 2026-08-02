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

export const API_ENDPOINT: string =
  process.env.EXPO_PUBLIC_API_ENDPOINT ?? 'http://localhost:3000/graphql';

export const isServerBackend = () => BACKEND === 'server';
