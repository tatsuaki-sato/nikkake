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

/**
 * 再送しても直らないエラーかどうか。
 * 恒久的ならキューから外して設定画面に出す。そうでなければ指数バックオフで再送する。
 */
export const isPermanent = (error: unknown): boolean => {
  if (error instanceof GraphQLRequestError) return error.permanent;
  return false;
};
