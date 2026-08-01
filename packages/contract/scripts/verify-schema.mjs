#!/usr/bin/env node
/**
 * schema.graphql が構文として正しく、想定した操作が揃っているかを検証する。
 *
 * Rails 実装後は `bundle exec rake graphql:dump` の出力とこのファイルが
 * 一致することも CI で検査する（生成物が腐るのを防ぐため）。
 *
 * 使い方: node packages/contract/scripts/verify-schema.mjs
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { buildSchema } from 'graphql';

const here = dirname(fileURLToPath(import.meta.url));
const schema = buildSchema(readFileSync(join(here, '..', 'schema.graphql'), 'utf8'));

/** 画面が依存する操作。減らすときは各クライアントの利用箇所も確認すること */
const REQUIRED_QUERIES = [
  'home', 'routines', 'routine', 'exercises',
  'workoutSession', 'progress', 'exerciseProgress', 'viewer', 'changes',
];

const REQUIRED_MUTATIONS = [
  'createAnonymousAccount', 'attachEmailPassword', 'linkExistingAccount', 'signOut',
  'createRoutine', 'updateRoutine', 'deleteRoutine', 'setRoutineActive', 'createCustomExercise',
  'recordWorkout', 'deleteRoutineLog', 'importSnapshot', 'resetData',
];

const problems = [];

const queries = schema.getQueryType()?.getFields() ?? {};
const mutations = schema.getMutationType()?.getFields() ?? {};

for (const name of REQUIRED_QUERIES) {
  if (!queries[name]) problems.push(`Query.${name} が無い`);
}
for (const name of REQUIRED_MUTATIONS) {
  if (!mutations[name]) problems.push(`Mutation.${name} が無い`);
}

// 「今日」はサーバが計算しない。日付を扱うクエリは today と timeZone を必ず受ける
for (const name of ['home', 'progress']) {
  const args = (queries[name]?.args ?? []).map((a) => a.name);
  for (const required of ['today', 'timeZone']) {
    if (!args.includes(required)) {
      problems.push(`Query.${name} に ${required} 引数が無い（サーバが「今日」を計算してはいけない）`);
    }
  }
}

// オフラインで作った記録を再送しても二重登録されないよう、id はクライアント生成
const recordWorkoutInput = schema.getType('RecordWorkoutInput')?.getFields() ?? {};
for (const required of ['id', 'logDate', 'timeZone']) {
  if (!recordWorkoutInput[required]) {
    problems.push(`RecordWorkoutInput.${required} が無い（冪等性とTZ保存に必要）`);
  }
}

// 入力エラーは payload の userErrors に入れる（文言が docs/FEATURES.md の仕様のため）
for (const [name, field] of Object.entries(mutations)) {
  const payload = field.type.ofType ?? field.type;
  const fields = typeof payload.getFields === 'function' ? payload.getFields() : {};
  if (!fields.userErrors) {
    problems.push(`Mutation.${name} の payload に userErrors が無い`);
  }
}

if (problems.length > 0) {
  console.error(`スキーマの検査に失敗 (${problems.length}件):\n  ${problems.join('\n  ')}`);
  process.exit(1);
}

console.log(
  `schema.graphql: OK  Query ${Object.keys(queries).length}本 / ` +
    `Mutation ${Object.keys(mutations).length}本 / ` +
    `型 ${Object.keys(schema.getTypeMap()).filter((n) => !n.startsWith('__')).length}個`,
);
