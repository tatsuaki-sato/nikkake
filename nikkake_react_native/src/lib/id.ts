/**
 * ローカル生成のIDは PostgreSQL の uuid 列にそのまま入る必要があるため、
 * RFC 4122 v4 準拠の文字列を返す。
 */

const hex: string[] = [];
for (let i = 0; i < 256; i++) {
  hex[i] = (i + 0x100).toString(16).slice(1);
}

const randomBytes = (length: number): Uint8Array => {
  const bytes = new Uint8Array(length);
  const cryptoObj: Crypto | undefined =
    typeof globalThis !== 'undefined' ? (globalThis as any).crypto : undefined;

  if (cryptoObj && typeof cryptoObj.getRandomValues === 'function') {
    cryptoObj.getRandomValues(bytes);
    return bytes;
  }

  for (let i = 0; i < length; i++) {
    bytes[i] = Math.floor(Math.random() * 256);
  }
  return bytes;
};

export const uuid = (): string => {
  const b = randomBytes(16);
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;

  return (
    hex[b[0]] + hex[b[1]] + hex[b[2]] + hex[b[3]] + '-' +
    hex[b[4]] + hex[b[5]] + '-' +
    hex[b[6]] + hex[b[7]] + '-' +
    hex[b[8]] + hex[b[9]] + '-' +
    hex[b[10]] + hex[b[11]] + hex[b[12]] + hex[b[13]] + hex[b[14]] + hex[b[15]]
  );
};

export const nowIso = (): string => new Date().toISOString();
