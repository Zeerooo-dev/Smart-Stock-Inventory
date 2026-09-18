# SmartStock Inventory System

SmartStock is an offline-first, cross-platform inventory management application built with Flutter, Material 3, and SQLite. One shared codebase powers responsive phone, tablet, and desktop interfaces. The Flutter rewrite is **2.0.0-beta.1**, intended for testing before a stable release.

## Platforms

| Platform | Source and verification status |
| --- | --- |
| Android | Runner included; local debug and release APK builds passed; device runtime not verified. Release signing currently uses a debug key. |
| Linux | Runner included; local release build passed on CachyOS x64; GUI runtime and other distributions not verified. |
| Windows | Runner included; CI build validation configured; device runtime not verified. |
| iOS / iPadOS | Runner included; macOS CI no-codesign build check configured. No signed IPA produced. |
| macOS | Runner included; build and runtime not verified. |
| Web | Runner and SQLite worker/WASM assets included; build and browser runtime not verified. |

Build success does not establish full production or device testing. Android emulator `emulator-5554` was not connected during initial validation.

## Features

- Inventory and supplier management
- Append-only stock audit ledger in application workflows, including reversal entries for rollbacks
- Restock and dispense operations
- Low-stock and reorder alerts
- Barcode labels and hardware barcode scanner input
- Reports and analytics
- CSV import/export and PDF export
- Multiple themes with Material 3 controls
- Responsive phone, tablet, and desktop navigation and layouts
- Local, offline SQLite storage
- Database backup/restore and migration of compatible legacy PyQt database schemas

Legacy encrypted Python Fernet files must first be opened and backed up by the PyQt application; only compatible plaintext SQLite backups can be imported.

The audit ledger is not a tamper-proof store against direct database edits. Keep a separate backup before importing an existing database, and verify imported data before relying on the beta.

## Development

Use Flutter **3.47.4 stable** (Dart 3.13.3), matching CI. Install the platform build tools for your target. `pubspec.lock` is tracked for reproducible application dependencies.

```sh
flutter pub get
flutter analyze
flutter test
```

Android:

```sh
flutter run -d <device>
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

Android release builds currently use the **debug signing key**. They are testing builds and are **not Play Store-ready**. Configure a private release keystore, appropriate application ID, and Play signing before distribution through Google Play. Never commit signing keys, credentials, or `android/key.properties`.

Linux:

```sh
flutter run -d linux
flutter build linux --release
```

Linux development requires Clang, CMake, Ninja, pkg-config, GTK 3 development libraries, SQLite, and libsecret development headers. Running the application also requires libsecret and an unlocked Secret Service keyring (such as GNOME Keyring or KWallet). Distribute the entire `build/linux/x64/release/bundle/` directory, including its `lib/` and `data/` folders. A bundle built on CachyOS may require newer system libraries than older Linux distributions provide.

Web:

```sh
flutter run -d chrome
```

The `web/` directory includes the SQLite worker and WASM files. If the SQLite web dependencies change, regenerate these files with `dart run sqflite_common_ffi_web:setup`. Browser storage is local to the browser/origin and can be cleared by the user or browser.

## iOS / iPadOS distribution

Normal signed App Store/TestFlight distribution requires macOS, Xcode, an Apple Developer account, a unique Bundle ID, a signing certificate, provisioning, App Store Connect, and TestFlight/App Store configuration.

The iOS source lives in `ios/` on the shared branch. CI uses a macOS runner for `flutter build ios --release --no-codesign`; this is a compilation check, not a signed IPA or a production download. Flutter resolves Swift Package Manager dependencies and uses CocoaPods for plugins that require it.

## CI and repository layout

`.github/workflows/flutter-ci.yml` runs analysis, tests, Android builds, Linux builds, Windows builds, and an iOS no-codesign build check on pull requests and pushes to `main`. Checks must actually pass before a migration is merged; configuration alone is not a passing result.

Shared application code lives in `lib/`, with platform configuration in `android/`, `ios/`, `linux/`, `windows/`, `macos/`, and `web/`. Use temporary development branches; do not create permanent per-platform branches. Compiled applications belong in GitHub Releases, not in source control.

The Android SQLite compatibility fix uses `rawQuery()` for both `PRAGMA journal_mode = DELETE` and `PRAGMA wal_checkpoint(FULL)`, because these statements return rows.

## Legacy PyQt Edition

The original Windows desktop edition built with Python, PyQt5, and SQLite remains available on [GitHub Releases](https://github.com/Zeerooo-dev/Smart-Stock-Inventory/releases). Users wanting the original edition can download **SmartStock_Setup.exe** from the existing [1.0.5 legacy release](https://github.com/Zeerooo-dev/Smart-Stock-Inventory/releases/tag/1.0.5).

The [v1.0.0-pyqt preservation release](https://github.com/Zeerooo-dev/Smart-Stock-Inventory/releases/tag/v1.0.0-pyqt) also contains the verified installer and snapshots the final legacy main commit. This is a preservation label for the same legacy code previously released as 1.0.5. Existing releases and tags remain preserved. The old executable is not part of the Flutter source tree, and the PyQt edition will no longer be the actively developed codebase after migration.

## Database keys and recovery

New encrypted database files use a random key stored by `flutter_secure_storage` in platform storage. There is no bundled database password. On Linux, a running and unlocked Secret Service keyring is required; on the web, use HTTPS or localhost and preserve browser storage. See the [secure-storage plugin documentation](https://pub.dev/packages/flutter_secure_storage) for platform requirements.

Older Flutter `SSG1` encrypted databases prompt for their previous passphrase and retain an encrypted `.legacy-backup` copy during migration. Incorrect passphrases, missing keys, and ambiguous plaintext/encrypted pairs leave the original files intact and stop startup instead of replacing data. The legacy passphrase is not shipped with the new app. Python Fernet files require export from PyQt first.

SQLite is plaintext while the app is open, and encryption happens only during a successful clean shutdown. Mobile operating systems may terminate the process without that callback; this feature is not full-disk encryption or a guarantee that the database is always encrypted at rest. Keep deliberate plaintext exports in a protected location for recovery and device transfers. An encrypted database alone is insufficient if its device key is lost.
