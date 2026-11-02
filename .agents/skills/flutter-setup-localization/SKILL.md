---
name: flutter-setup-localization
description: Use when changing Flutter locale support, translated messages, or locale-sensitive date and number formatting.
---
# Flutter localization

## Scope before setup

Read `pubspec.yaml` and the `MaterialApp` in `lib/main.dart`. This project already has `flutter_localizations`, `intl`, global Material/Widgets delegates and ru/en supported locales. Much application copy is inline; built-in widget localization does not translate that copy. A copy or date-format fix is not permission to introduce an ARB/code-generation migration.

For formatting-only work, reuse `intl` and the existing locale policy. Below the app's localization scope, obtain the active locale with `Localizations.localeOf(context).toString()` and pass it to `DateFormat`/`NumberFormat`. Keep time-zone and money-unit behavior unchanged. Check existing date-symbol initialization before adding any. Do not loosen package constraints to `intl:any` or repeat dependency installation.

## Only for an explicitly requested ARB pipeline

1. Agree the source locale, translated locales and copy scope; do not invent translations. Enable `generate: true` under the existing `flutter:` section of `pubspec.yaml`.
2. Create `l10n.yaml` with source output, for example:

   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_ru.arb
   output-localization-file: app_localizations.dart
   ```

   On this Flutter 3.41+ project, omit the obsolete `synthetic-package` option. Do not use `synthetic-package: true` or `package:flutter_gen`.
3. Define matching keys and metadata in `app_ru.arb` and the approved translations. For plurals, include the locale's required categories and `other`; give placeholders types and descriptions. For example:

   ```json
   {
     "items": "{count, plural, one{{count} товар} few{{count} товара} many{{count} товаров} other{{count} товара}}",
     "@items": {"placeholders": {"count": {"type": "int"}}}
   }
   ```

4. Run `flutter gen-l10n`. Import the generated source as `package:naliv_delivery/l10n/app_localizations.dart`. If `output-dir` is chosen, update the import to that actual source path. Never edit generated Dart by hand.
5. Use `AppLocalizations.localizationsDelegates` and `.supportedLocales` in the existing app without discarding its navigator, observers, themes or entry gate. Consume messages below that scope; preserve any additional delegates.

Test approved locales, placeholder/plural boundaries, long text and fallback behavior in existing widget fixtures; validate only synthetic content. Run the affected test via `dart run tool/design_harness.dart check <existing-test-path>`.

Reference: [generated localization source migration](https://docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source).
