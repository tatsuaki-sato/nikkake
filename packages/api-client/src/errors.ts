export class GraphQLRequestError extends Error {
  constructor(
    message: string,
    readonly code: string | null = null,
    readonly permanent = false,
  ) {
    super(message);
    this.name = 'GraphQLRequestError';
  }
}

/** サーバへ届かなかったのか、届いたうえで断られたのか */
export const isNetworkError = (error: unknown): boolean =>
  error instanceof GraphQLRequestError && error.code === 'NETWORK';

/**
 * 圏外のときに保存系の画面へ出す文言。
 *
 * navigator.onLine では判定しない。Wi-Fi に繋がっていてもサーバへ届かないことがあり、
 * 逆に onLine が false でも届くことがある。実際に送ってみた結果で判断する。
 */
export const OFFLINE_SAVE_MESSAGE =
  'オフラインのため保存できません。電波のあるところで試してください。';

/**
 * 再送しても直らないエラーかどうか。
 * 恒久的ならキューから外して設定画面に出す。そうでなければ指数バックオフで再送する。
 */
export const isPermanent = (error: unknown): boolean => {
  if (error instanceof GraphQLRequestError) return error.permanent;
  return false;
};
