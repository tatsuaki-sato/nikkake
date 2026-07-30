# Nikkake Multi-Platform Agent Rules

This workspace contains 3 parallel implementations of the Nikkake app.
Agents MUST read the `DEVELOPMENT_CONTEXT.md` in each respective directory before making modifications.

## Workspace Structure
- `/Users/tatsuaki/dev/hotl-star/nikkake_ref`: React Native / Expo implementation.
  - Core Stack: TypeScript, React Native, Expo, Expo Router, Zustand, @supabase/supabase-js, Playwright.
- `/Users/tatsuaki/dev/hotl-star/nikkake_flutter`: Flutter implementation.
  - Core Stack: Dart, Flutter, Provider, supabase_flutter, go_router, integration_test.
- `/Users/tatsuaki/dev/hotl-star/nikkake_kmp`: Kotlin Multiplatform implementation.
  - Core Stack: Kotlin, Compose Multiplatform, supabase-kt, Voyager.

## Cross-Platform Sync Rules
When adding a new feature or modifying the data schema (Supabase), you MUST:
1. Propose the change and confirm which platform(s) should be updated.
2. If updating all platforms, ensure the UI/UX, Color Theme, and test coverage remain identical across React Native, Flutter, and KMP.
3. Use the platform-specific testing tools to verify your implementation before considering the task complete.
