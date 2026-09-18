# SmartStock Phase 1 + 2 Manual Validation Guide

This build introduces the **Stock Movement Service** and **Sales / Quick Checkout**. It also upgrades the SQLite schema to version 2 by adding sales tables and ledger source-reference fields.

## Before you apply the patch

1. **Back up your current database** from SmartStock Settings.
2. Make a source-code backup or Git commit of your current working tree.
3. Do not test first against your only production database. Use a copy or `--test` sandbox mode on desktop when practical.

## Apply and validate the code

From the root of your real Git repository:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then build both currently tested targets:

```bash
flutter build apk --release
flutter build linux --release
```

If analysis, tests, or either build reports a real error, fix that before using a production database.

## Linux migration smoke test

1. Start SmartStock with an existing v2.0.x database.
2. Confirm existing inventory, categories, suppliers, audit history, settings, and themes are still present.
3. Open **Sales**. It should load without a database/schema error.
4. Restart the app once and confirm the migrated database opens again.

The migration is additive: it adds `Sale`, `SaleItem`, and source-reference columns to `InventoryLedger`.

## Sale test — one product

Prepare an item with a known quantity, for example:

- Product: Test Cola
- Starting quantity: 10
- Price: ₱25.00

Then:

1. Open **Sales**.
2. Search for Test Cola.
3. Add quantity **3** to the cart.
4. Complete the sale.
5. Verify Inventory now shows **7**.
6. Verify Recent Sales shows a new `SALE-xxxxxx` transaction totaling **₱75.00**.
7. Open Audit and verify a **SALE** entry exists with delta **-3** and the sale number as its reference.
8. Open the product history and verify the same movement appears there.

## Multi-product atomic transaction test

1. Add two products to one sale.
2. Complete the sale.
3. Confirm both quantities decrease and both ledger rows reference the same sale number.
4. Confirm the Sale detail contains both lines and the correct total.

### Insufficient-stock atomicity test

The whole transaction must fail together.

1. Put Product A and Product B in a sale.
2. Before completing, reduce Product B's available stock from another app session/test step so the cart becomes stale, or otherwise arrange for requested stock to exceed the database quantity at checkout time.
3. Attempt to complete the sale.
4. Confirm SmartStock reports insufficient stock.
5. Confirm **neither Product A nor Product B changed quantity**.
6. Confirm **no partial Sale and no partial SALE ledger rows were committed**.

## Sale void test

1. Complete a sale containing two or more products.
2. Note each product's post-sale quantity.
3. Open that transaction in Recent Sales.
4. Choose **Void Sale** and confirm.
5. Verify every sold quantity is restored.
6. Verify the original transaction still exists and is marked **VOIDED**.
7. Verify Audit contains `ROLLBACK_REVERSAL` rows referencing the same sale number.
8. Verify the original `SALE` rows remain in the audit trail.

## Audit safety test

1. Select a normal manual quantity-change ledger row: existing rollback behavior should still work when valid.
2. Select a `SALE` row: individual rollback must be disabled/rejected.
3. Sale reversal must happen through **Sales → Void Sale**, so the full transaction stays consistent.
4. A `ROLLBACK_REVERSAL` entry must not itself be roll-backable.

## Barcode-scanner test

If you have a USB/Bluetooth scanner that acts as a keyboard:

1. Open **Sales**.
2. Scan a known SmartStock SKU/barcode while no ordinary text input has keyboard focus.
3. Confirm the item is added to the cart.
4. Scan the same barcode again and confirm quantity increments by one, up to available stock.
5. Scan an unknown barcode and confirm stock is not changed.

You can also focus the Sales search field, scan/type an exact SKU, and press Enter to add it.

## Android test

Run:

```bash
flutter run -d emulator-5554
```

or use your physical Android device ID.

Repeat at minimum:

- existing database migration/startup
- product search
- add/remove cart line
- quantity +/- controls
- complete sale
- sale detail
- void sale
- Audit SALE reference
- bottom navigation / More menu
- rotation or several emulator widths to check for RenderFlex overflow

Also confirm the earlier Android SQLite fix is still effective: startup must not fail on `PRAGMA journal_mode = DELETE`.

## Legacy import / backup test

1. Create a SmartStock database backup before this feature.
2. Import/restore it into this build.
3. Confirm it migrates and Sales opens.
4. Create a sale.
5. Back up the now-migrated database.
6. Restore that backup and verify the sale/history remains.

## Expected movement types after Phase 1 + 2

Current supported quantity/audit types in this phase are:

- `CREATE`
- `MANUAL_EDIT`
- `CSV_IMPORT`
- `SALE`
- `ROLLBACK_REVERSAL`

Generic `RESTOCK` and `DISPENSE` workflows are intentionally not reintroduced.

## Do not release until these are true

- `flutter analyze` passes without errors.
- `flutter test` passes.
- Android release build succeeds.
- Linux release build succeeds.
- Existing database opens without losing data.
- A sale deducts correct stock and records correct history.
- A failed sale makes zero partial changes.
- Voiding a sale restores every product exactly once.
- No RenderFlex errors appear in the Sales flow on phone/tablet/desktop widths.
