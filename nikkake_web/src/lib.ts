import { NikkakeApi, browserStore } from '@nikkake/api-client';

/** 画面から使う唯一のAPIインスタンス */
export const api = new NikkakeApi(browserStore(), '/graphql');

export const hexToStyle = (hex: string) => ({ backgroundColor: hex });
