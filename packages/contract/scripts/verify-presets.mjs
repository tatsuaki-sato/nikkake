#!/usr/bin/env node
/**
 * プリセット種目が4か所すべてで一致しているかを検証する。
 *
 *   packages/contract/preset_exercises.json  ← 唯一の正
 *     ├── nikkake_react_native/src/constants/exercises.ts
 *     ├── nikkake_flutter/lib/constants/exercises.dart
 *     ├── nikkake_kmp/shared/.../constants/Exercises.kt
 *     └── nikkake_react_native/supabase/migrations/20260801000000_local_first_sync.sql
 *
 * 固定UUIDがズレるとクラウド同期で同じ種目が重複するため、CI で必ず回すこと。
 * 使い方: node packages/contract/scripts/verify-presets.mjs
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const read = (p) => readFileSync(join(repoRoot, p), 'utf8');

const truth = JSON.parse(read('packages/contract/preset_exercises.json')).exercises;
const problems = [];

/** 抽出結果を正と突き合わせる。順序も一致していること */
const compare = (label, rows, fields) => {
  if (rows.length !== truth.length) {
    problems.push(`${label}: 件数が違う (期待 ${truth.length} / 実際 ${rows.length})`);
    return;
  }
  truth.forEach((want, i) => {
    const got = rows[i];
    for (const f of fields) {
      if (String(got[f]) !== String(want[f])) {
        problems.push(`${label}[${i}] ${f}: 期待 '${want[f]}' / 実際 '${got[f]}' (${want.name})`);
      }
    }
  });
};

// --- React Native (TypeScript) ---
const tsRe = /\{\s*id:\s*presetId\((\d+)\),\s*name:\s*'([^']+)',\s*category:\s*'([^']+)',\s*icon:\s*'([^']+)'(?:,\s*bodyweight:\s*(true|false))?(?:,\s*timeBased:\s*(true|false))?\s*\}/g;
compare(
  'React Native',
  [...read('nikkake_react_native/src/constants/exercises.ts').matchAll(tsRe)].map((m) => ({
    id: `00000000-0000-4000-8000-${String(m[1]).padStart(12, '0')}`,
    name: m[2], category: m[3], icon: m[4],
    bodyweight: m[5] === 'true', timeBased: m[6] === 'true',
  })),
  ['id', 'name', 'category', 'icon', 'bodyweight', 'timeBased'],
);

// --- Flutter (Dart) ---
const dartRe = /PresetExercise\(id:\s*'([^']+)',\s*name:\s*'([^']+)',\s*category:\s*ExerciseCategory\.(\w+),\s*icon:\s*'([^']+)'(?:,\s*bodyweight:\s*(true|false))?(?:,\s*timeBased:\s*(true|false))?\)/g;
compare(
  'Flutter',
  [...read('nikkake_flutter/lib/constants/exercises.dart').matchAll(dartRe)].map((m) => ({
    id: m[1], name: m[2], category: m[3], icon: m[4],
    bodyweight: m[5] === 'true', timeBased: m[6] === 'true',
  })),
  ['id', 'name', 'category', 'icon', 'bodyweight', 'timeBased'],
);

// --- KMP (Kotlin) ---
const ktRe = /PresetExercise\(presetId\((\d+)\),\s*"([^"]+)",\s*ExerciseCategory\.(\w+),\s*"([^"]+)"(?:,\s*bodyweight\s*=\s*(true|false))?(?:,\s*timeBased\s*=\s*(true|false))?\)/g;
compare(
  'KMP',
  [...read('nikkake_kmp/shared/src/commonMain/kotlin/com/myapplication/common/constants/Exercises.kt').matchAll(ktRe)].map((m) => ({
    id: `00000000-0000-4000-8000-${String(m[1]).padStart(12, '0')}`,
    name: m[2], category: m[3].toLowerCase(), icon: m[4],
    bodyweight: m[5] === 'true', timeBased: m[6] === 'true',
  })),
  ['id', 'name', 'category', 'icon', 'bodyweight', 'timeBased'],
);

// --- SQL マイグレーション（bodyweight/timeBased は持たない） ---
const sqlRe = /\('(00000000-0000-4000-8000-\d{12})',\s*'([^']+)',\s*'([^']+)',\s*'([^']*)',\s*'([^']+)',\s*TRUE\)/g;
compare(
  'SQL',
  [...read('nikkake_react_native/supabase/migrations/20260801000000_local_first_sync.sql').matchAll(sqlRe)].map((m) => ({
    id: m[1], name: m[2], category: m[3], description: m[4], icon: m[5],
  })),
  ['id', 'name', 'category', 'icon', 'description'],
);

if (problems.length > 0) {
  console.error(`プリセット種目が一致していません (${problems.length}件):\n  ${problems.join('\n  ')}`);
  process.exit(1);
}
console.log(`プリセット種目 ${truth.length}件: React Native / Flutter / KMP / SQL の4か所すべて一致`);
