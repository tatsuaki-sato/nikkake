import { GraphQLRequestError } from './errors';
import { currentTimeZone } from '@nikkake/domain';

export interface ClientOptions {
  endpoint: string;
  /** ネイティブは Bearer トークン。Web は httpOnly Cookie を使うので null */
  getToken?: () => string | null;
  /** Web で Cookie を送るために必要 */
  credentials?: RequestCredentials;
}

export interface GraphQLResponse<T> {
  data?: T;
  errors?: Array<{ message: string; extensions?: { code?: string } }>;
}

export class GraphQLClient {
  constructor(private readonly options: ClientOptions) {}

  async request<T>(query: string, variables: Record<string, unknown> = {}): Promise<T> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      // サーバは「今日」を計算しない。TZは常にクライアントが伝える
      'X-Nikkake-Timezone': currentTimeZone(),
    };

    const token = this.options.getToken?.();
    if (token) headers.Authorization = `Bearer ${token}`;

    let response: Response;
    try {
      response = await fetch(this.options.endpoint, {
        method: 'POST',
        headers,
        credentials: this.options.credentials ?? 'same-origin',
        body: JSON.stringify({ query, variables }),
      });
    } catch (e) {
      // ネットワーク到達不能。再送する価値があるので permanent=false
      throw new GraphQLRequestError(
        e instanceof Error ? e.message : 'ネットワークに接続できません',
        'NETWORK',
        false,
      );
    }

    if (!response.ok) {
      // 4xx は再送しても直らない。5xx は一時的な可能性がある
      const permanent = response.status >= 400 && response.status < 500;
      throw new GraphQLRequestError(`サーバエラー (${response.status})`, String(response.status), permanent);
    }

    const body = (await response.json()) as GraphQLResponse<T>;

    if (body.errors?.length) {
      const first = body.errors[0];
      const code = first.extensions?.code ?? null;
      // 認証切れやスキーマ不一致は再送しても直らない
      const permanent = code !== null && code !== 'NETWORK';
      throw new GraphQLRequestError(first.message, code, permanent);
    }

    if (!body.data) throw new GraphQLRequestError('応答が空です', null, false);
    return body.data;
  }
}
