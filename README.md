# SmartStock Inventory System

SmartStock is an offline-first, cross-platform inventory management application built with Flutter, Material 3, and SQLite. One shared codebase powers responsive phone, tablet, and desktop interfaces. The current application version is **2.0.1+3**. The active implementation is Flutter; the former Python/PyQt edition is preserved in historical releases.

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
- CSV/XLSX inventory import, XLSX spreadsheet export, and PDF export
- Multiple themes with Material 3 controls
- Responsive phone, tablet, and desktop navigation and layouts
- Local, offline SQLite storage
- Database backup/restore and migration of compatible legacy PyQt database schemas

Legacy encrypted Python Fernet files must first be opened and backed up by the PyQt application; only compatible plaintext SQLite backups can be imported.

The audit ledger is not a tamper-proof store against direct database edits. Keep a separate backup before importing an existing database, and verify imported data before relying on it.

## Inventory workflow and notifications

- Clicking an inventory row/card, double-clicking, or activating it with Enter/Space opens an **Item Details** dialog with read-only item information, a barcode preview, and Restock/Dispense actions. Selection and barcode scanning do not enter edit mode.
- **Item Actions → Edit** is the only way to populate the editable form. Save Changes commits an edit; Cancel Editing returns to an empty Add Item form.
- **Restock**, **Dispense**, and the barcode preview appear in **Item Details** when you open an inventory row/card. Stock changes apply to that item and refresh the dialog quantity, value, and low-stock status after success. These controls no longer appear in the Add Item form or action menu.
- Quantity and Unit Price start empty with input hints. Quantity must be a non-negative whole number; price must be a finite non-negative amount with at most two decimal places in the form. Successful additions refresh inventory, clear the form, and display **Item Added Successfully**.
- Deleting an item records a `DELETE` audit entry with its name, SKU, price, and quantities (remaining stock → 0), including in Audit PDF/XLSX and Reports. Inventory reset also records each deletion. Deletion and logging commit together; a failure rolls both back. Deletions made before this change cannot be reconstructed reliably.
- Inventory card icons show name initials; quantities appear in a separate badge.
- Stock adjustments accept an optional transaction note. Dispensing beyond available stock is rejected without changing inventory or writing an audit record.
- A centralized, best-effort **in-app notification** helper displays add-item confirmations, low-stock alerts, and successful audit export confirmations. It does not require system-tray permissions; it does not send OS notifications while the app is closed.
- The low-stock monitor checks all inventory once per minute while the app runs and immediately after inventory mutations. It uses the existing rule `Quantity < ReorderLevel`, tracks item IDs, and alerts only when an item enters the low state. Remaining low (even at a lower quantity) does not repeat the alert. Returning to the threshold or above rearms the alert. Multiple newly low items are summarized in one notification. The initial inventory establishes a baseline on each launch.

## Reports and audit exports

All four export paths use the same stored ledger snapshots: **Reports XLSX, Reports PDF, Audit XLSX, and Audit PDF** include **Quantity Before**, **Quantity Changed**, and **Quantity After**. For example, restocking 20 by 10 displays `20, +10, 30`; dispensing 6 afterward displays `30, -6, 24`. XLSX quantities remain numeric cells with display formats for commas and signs.

- Reports PDF retains the inventory summary and totals, then adds a landscape transaction-history section. Reports XLSX separates Inventory and Transaction History into worksheets. Transaction columns in PDF and XLSX are Item, SKU, Unit Price, Quantity Before, Quantity Changed, Quantity After, Date/Time (UTC), Transaction Type, and Notes. Inventory import accepts existing CSV files, the Inventory sheet of a SmartStock XLSX report, or another worksheet with the required inventory columns; it ignores transaction rows in legacy combined CSV reports and skips the XLSX totals row.
- Audit Log offers **Export Audit XLSX** and **Export Audit PDF** using its item/type/date filters. Item History XLSX uses the same stored quantities. Filtering and pagination do not recalculate balances.
- PDFs use embedded offline fonts, Philippine-peso-compatible text, landscape transaction tables, repeating column headers, page numbers, and continuation rows for long text. The bundled Carlito fonts are covered by the included SIL Open Font License.
- Export success is shown only after the Save File operation returns a saved file. Cancellation shows no success; generation and save errors are reported. Scheduled reports reuse the same XLSX/PDF builders.

### Database compatibility

On opening the database, a transactional, repeatable migration inspects `PRAGMA table_info` and adds missing nullable `QuantityBefore`, `QuantityAfter`, `SkuSnapshot`, and `Notes` columns to `InventoryLedger`. Existing `DeltaQuantity` remains the signed change. Existing rows, categories, suppliers, and settings are preserved. Old rows without captured balances export **N/A**; no historical quantities are guessed.

For every new adjustment, SQLite reads the current quantity inside the same transaction that validates the amount, updates inventory, and inserts the ledger row. `QuantityBefore` is that original value and `QuantityAfter` is the original value plus the signed delta. A failure in either write rolls back both. Creation, CSV import, manual quantity edits, and rollback reversals also capture snapshots. Names and SKUs are retained in new ledger entries even after item deletion. Encryption and the Android `rawQuery` PRAGMA fixes are unchanged.

The visible application name is **SmartStock**. The `pubspec.yaml` `name` remains `smartstock_flutter`, a lowercase Dart package identifier; application IDs, executable names, database paths, and the release version remain stable.

## Development

Use Flutter **3.47.4 stable** (Dart 3.13.3), matching CI. Install the platform build tools for your target. `pubspec.lock` is tracked for reproducible application dependencies.

```sh
flutter pub get
flutter analyze
flutter test
```

The transaction tests cover migration, rollback on ledger-write failure, concurrent dispense protection, all four exports, notifications, and desktop/mobile row activation. To additionally check generated PDF text using Poppler and save review samples under `/tmp/smartstock-pdf-qa`:

```sh
SMARTSTOCK_PDF_QA=1 flutter test test/stock_transactions_test.dart
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
