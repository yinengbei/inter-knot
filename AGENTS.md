# Repository Guidelines

## Project Structure & Module Organization
- Flutter client lives in `lib/` (entry: `lib/main.dart`) with UI in `lib/pages/` and reusable widgets in `lib/components/`.
- Shared logic and models are in `lib/controllers/`, `lib/models/`, `lib/helpers/`, and constants in `lib/constants/`.
- Static assets are under `assets/` (images/fonts), configured in `pubspec.yaml`.
- Backend service is in `inter-knot-server/` (TypeScript, Prisma) with source in `inter-knot-server/src/` and schema in `inter-knot-server/prisma/`.
- Platform-specific wrappers are in `android/`, `ios/`, `macos/`, `windows/`, `linux/`, and `web/`.

## Build, Test, and Development Commands
Flutter (run from repo root):
- `flutter pub get` — install Dart/Flutter dependencies.
- `flutter run` — run the app on a connected device/emulator.
- `flutter build apk` / `flutter build ios` / `flutter build web` — platform builds.
- `dart run build_runner build` — codegen tasks (e.g., assets/gen).

Server (run from `inter-knot-server/`):
- `npm install` — install Node dependencies.
- `npm run start` — start the TypeScript server via `ts-node`.
- `npm run build` — compile TypeScript to `dist/`.

## Coding Style & Naming Conventions
- Dart lints: `analysis_options.yaml` uses `package:lint/strict.yaml` with `prefer_single_quotes: true`.
- Use lower_snake_case for Dart file names (existing pattern in `lib/`).
- Keep Flutter widgets and classes in `UpperCamelCase`.
- TypeScript follows standard `tsconfig.json` settings; keep files in `src/` and output in `dist/`.

## Testing Guidelines
- Flutter tests use `flutter_test` (no top-level `test/` directory currently).
- iOS/macOS runner tests exist under `ios/RunnerTests/` and `macos/RunnerTests/`.
- Until tests are added, validate changes by running the app (`flutter run`) and server (`npm run start`).

## Commit & Pull Request Guidelines
- Commit history is inconsistent (mix of Conventional Commits like `chore: ...` and free-form messages). Prefer Conventional Commits for new work (e.g., `feat: add login flow`).
- PRs should include: a brief summary, key screenshots for UI changes, and any relevant platform notes (e.g., web vs. mobile behavior).
- If touching backend schema, mention Prisma migration changes in the PR description.

## Security & Configuration Tips
- Secrets should not be committed; use local configuration or tooling (see `gen_secrets.dart`).
- Review `SECURITY.md` before handling auth or token-related changes.
