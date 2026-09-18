import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../data/database_service.dart';
import '../models/models.dart';
import '../services/export_service.dart';
import '../services/database_crypto.dart';
import '../services/scheduled_report_writer.dart';

enum AppSection { inventory, sales, reports, audit, suppliers, settings }

enum ScheduledFormat { csvOnly, pdfOnly, csvAndPdf }

extension ScheduledFormatLabel on ScheduledFormat {
  String get label => switch (this) {
        ScheduledFormat.csvOnly => 'CSV only',
        ScheduledFormat.pdfOnly => 'PDF only',
        ScheduledFormat.csvAndPdf => 'Both CSV and PDF',
      };
}

class SmartStockController extends ChangeNotifier {
  SmartStockController({this.sandbox = false});

  final bool sandbox;
  final DatabaseService database = DatabaseService();
  late final ExportService exports = ExportService(database);

  bool loading = true;
  String? startupError;
  bool needsLegacyPassphrase = false;
  String statusMessage = 'Ready';
  AppSection section = AppSection.inventory;
  SmartStockTheme theme = SmartStockTheme.defaultLight;
  Color? customAccent;

  List<CategoryRecord> categories = const [];
  InventoryPage inventoryPage = const InventoryPage(items: [], total: 0);
  int inventoryPageIndex = 0;
  String inventorySearch = '';
  InventoryItem? selectedItem;

  String saleSearch = '';
  List<InventoryItem> saleSearchResults = const [];
  List<SaleCartLine> saleCart = const [];
  List<SaleRecord> recentSales = const [];
  bool saleBusy = false;

  double get saleCartTotal => saleCart.fold(0.0, (sum, line) => sum + line.subtotal);
  int get saleCartUnits => saleCart.fold(0, (sum, line) => sum + line.quantity);

  KpiSnapshot kpis = KpiSnapshot.empty;
  List<CategorySummary> categorySummaries = const [];
  List<LowStockThreat> lowStockThreats = const [];

  List<String> auditItemNames = const [];
  LedgerPage auditPage = const LedgerPage(entries: [], total: 0);
  int auditPageIndex = 0;
  AuditFilter auditFilter = AuditFilter(
    dateFrom: DateTime.now().subtract(const Duration(days: 30)),
    dateTo: DateTime.now(),
  );
  LedgerEntry? selectedLedgerEntry;

  List<SupplierRecord> suppliers = const [];
  SupplierRecord? selectedSupplier;

  Timer? _scheduler;
  bool schedulerRunning = false;
  int schedulerIntervalMinutes = 60;
  ScheduledFormat schedulerFormat = ScheduledFormat.csvOnly;
  String schedulerOutputDirectory = '';

  int get inventoryTotalPages {
    final pages = (inventoryPage.total / DatabaseService.inventoryPageSize).ceil();
    return pages < 1 ? 1 : pages;
  }

  int get auditTotalPages {
    final pages = (auditPage.total / DatabaseService.auditPageSize).ceil();
    return pages < 1 ? 1 : pages;
  }

  Future<void> initialize({String? legacyPassphrase}) async {
    loading = true;
    needsLegacyPassphrase = false;
    notifyListeners();
    try {
      await database.initialize(
        sandbox: sandbox,
        legacyPassphrase: legacyPassphrase,
      );
      await refreshAll();
      startupError = null;
      statusMessage = sandbox ? 'Sandbox database loaded.' : 'SmartStock ready.';
    } catch (e) {
      needsLegacyPassphrase =
          e is LegacyDatabaseKeyRequired || legacyPassphrase != null;
      startupError = e.toString();
      statusMessage = 'Startup failed.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshCategories(notify: false),
      refreshInventory(notify: false),
      refreshSales(notify: false),
      refreshReports(notify: false),
      refreshAudit(notify: false),
      refreshSuppliers(notify: false),
    ]);
    notifyListeners();
  }

  void goTo(AppSection next) {
    section = next;
    if (next == AppSection.sales) unawaited(refreshSales());
    if (next == AppSection.reports) unawaited(refreshReports());
    if (next == AppSection.audit) unawaited(refreshAudit());
    if (next == AppSection.suppliers) unawaited(refreshSuppliers());
    notifyListeners();
  }

  void setStatus(String text) {
    statusMessage = text;
    notifyListeners();
  }

  Future<void> refreshCategories({bool notify = true}) async {
    categories = await database.getCategories();
    if (notify) notifyListeners();
  }

  Future<void> refreshInventory({bool notify = true}) async {
    inventoryPage = await database.getInventoryPage(search: inventorySearch, page: inventoryPageIndex);
    final totalPages = inventoryTotalPages;
    if (inventoryPageIndex >= totalPages) {
      inventoryPageIndex = totalPages - 1;
      inventoryPage = await database.getInventoryPage(search: inventorySearch, page: inventoryPageIndex);
    }
    if (selectedItem != null) {
      InventoryItem? freshSelection;
      for (final item in inventoryPage.items) {
        if (item.id == selectedItem!.id) {
          freshSelection = item;
          break;
        }
      }
      selectedItem = freshSelection;
    }
    if (notify) notifyListeners();
  }

  Future<void> setInventorySearch(String value) async {
    inventorySearch = value.trim();
    inventoryPageIndex = 0;
    await refreshInventory();
  }

  Future<void> inventoryPrev() async {
    if (inventoryPageIndex <= 0) return;
    inventoryPageIndex--;
    await refreshInventory();
  }

  Future<void> inventoryNext() async {
    if ((inventoryPageIndex + 1) * DatabaseService.inventoryPageSize >= inventoryPage.total) return;
    inventoryPageIndex++;
    await refreshInventory();
  }

  void selectItem(InventoryItem? item) {
    selectedItem = item;
    notifyListeners();
  }

  Future<void> addItem({
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int reorderLevel,
  }) async {
    await database.addItem(
      name: name,
      category: category,
      quantity: quantity,
      unitPrice: unitPrice,
      reorderLevel: reorderLevel,
    );
    selectedItem = null;
    statusMessage = "'$name' added to inventory.";
    await _refreshAfterInventoryMutation();
  }

  Future<void> updateItem({
    required int itemId,
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int reorderLevel,
  }) async {
    await database.updateItem(
      itemId: itemId,
      name: name,
      category: category,
      quantity: quantity,
      unitPrice: unitPrice,
      reorderLevel: reorderLevel,
    );
    selectedItem = null;
    statusMessage = 'Item #${itemId.toString().padLeft(5, '0')} updated.';
    await _refreshAfterInventoryMutation();
  }

  Future<void> deleteItem(InventoryItem item) async {
    await database.deleteItem(item.id);
    selectedItem = null;
    statusMessage = "'${item.name}' deleted.";
    await _refreshAfterInventoryMutation();
  }


  Future<void> _refreshAfterInventoryMutation() async {
    await Future.wait([
      refreshInventory(notify: false),
      refreshSales(notify: false),
      refreshReports(notify: false),
      refreshAudit(notify: false),
    ]);
    notifyListeners();
  }

  Future<void> refreshSales({bool notify = true}) async {
    saleSearchResults = await database.searchSaleInventory(saleSearch);
    recentSales = await database.getRecentSales();
    if (saleCart.isNotEmpty) {
      final freshItems = await database.getInventoryItemsByIds(saleCart.map((line) => line.item.id));
      final byId = {for (final item in freshItems) item.id: item};
      final refreshedCart = <SaleCartLine>[];
      for (final line in saleCart) {
        final item = byId[line.item.id];
        if (item == null || item.quantity <= 0) continue;
        final quantity = line.quantity > item.quantity ? item.quantity : line.quantity;
        refreshedCart.add(line.copyWith(item: item, quantity: quantity));
      }
      saleCart = refreshedCart;
    }
    if (notify) notifyListeners();
  }

  Future<void> setSaleSearch(String value) async {
    saleSearch = value.trim();
    saleSearchResults = await database.searchSaleInventory(saleSearch);
    notifyListeners();
  }

  Future<void> addSaleItem(InventoryItem item, {int quantity = 1}) async {
    if (quantity <= 0) return;
    if (item.quantity <= 0) {
      throw StateError("'${item.name}' is out of stock.");
    }
    final index = saleCart.indexWhere((line) => line.item.id == item.id);
    final current = index < 0 ? 0 : saleCart[index].quantity;
    final next = current + quantity;
    if (next > item.quantity) {
      throw StateError("Only ${item.quantity} unit(s) of '${item.name}' are available.");
    }
    final updated = [...saleCart];
    if (index < 0) {
      updated.add(SaleCartLine(item: item, quantity: quantity));
    } else {
      updated[index] = updated[index].copyWith(quantity: next, item: item);
    }
    saleCart = updated;
    statusMessage = "Added '${item.name}' to sale.";
    notifyListeners();
  }

  void setSaleCartQuantity(int itemId, int quantity) {
    final index = saleCart.indexWhere((line) => line.item.id == itemId);
    if (index < 0) return;
    if (quantity <= 0) {
      removeSaleCartItem(itemId);
      return;
    }
    final line = saleCart[index];
    if (quantity > line.item.quantity) {
      throw StateError("Only ${line.item.quantity} unit(s) of '${line.item.name}' are available.");
    }
    final updated = [...saleCart];
    updated[index] = line.copyWith(quantity: quantity);
    saleCart = updated;
    notifyListeners();
  }

  void removeSaleCartItem(int itemId) {
    saleCart = saleCart.where((line) => line.item.id != itemId).toList(growable: false);
    notifyListeners();
  }

  void clearSaleCart() {
    saleCart = const [];
    statusMessage = 'Sale cart cleared.';
    notifyListeners();
  }

  Future<void> beginSaleWithItem(InventoryItem item) async {
    section = AppSection.sales;
    await refreshSales(notify: false);
    await addSaleItem(item);
    notifyListeners();
  }

  Future<bool> tryAddSaleSearch(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return false;
    final exact = await database.findItemBySku(clean);
    if (exact != null) {
      await addSaleItem(exact);
      saleSearch = '';
      saleSearchResults = await database.searchSaleInventory('');
      notifyListeners();
      return true;
    }
    final matches = await database.searchSaleInventory(clean, limit: 2);
    if (matches.length == 1) {
      await addSaleItem(matches.first);
      return true;
    }
    return false;
  }

  Future<void> addSaleBySku(String sku) async {
    final item = await database.findItemBySku(sku);
    if (item == null) {
      statusMessage = 'Barcode not found: $sku';
      notifyListeners();
      return;
    }
    await addSaleItem(item);
    saleSearch = '';
    saleSearchResults = await database.searchSaleInventory('');
    statusMessage = "Scanned '${item.name}' into the sale.";
    notifyListeners();
  }

  Future<void> handleScannedSku(String sku) async {
    try {
      if (section == AppSection.sales) {
        await addSaleBySku(sku);
      } else {
        await locateSku(sku);
      }
    } catch (e) {
      statusMessage = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
    }
  }

  Future<SaleRecord> completeSale({String notes = ''}) async {
    if (saleCart.isEmpty) throw StateError('Add at least one item before completing the sale.');
    saleBusy = true;
    notifyListeners();
    try {
      final sale = await database.completeSale(
        saleCart.map((line) => SaleDraftLine(itemId: line.item.id, quantity: line.quantity)).toList(),
        notes: notes,
      );
      saleCart = const [];
      saleSearch = '';
      statusMessage = '${sale.saleNumber} completed · ${sale.totalItems} unit(s) · ₱${sale.totalAmount.toStringAsFixed(2)}.';
      await Future.wait([
        refreshInventory(notify: false),
        refreshSales(notify: false),
        refreshReports(notify: false),
        refreshAudit(notify: false),
      ]);
      notifyListeners();
      return sale;
    } finally {
      saleBusy = false;
      notifyListeners();
    }
  }

  Future<SaleDetail> getSaleDetail(int saleId) => database.getSaleDetail(saleId);

  Future<void> voidSale(SaleRecord sale) async {
    saleBusy = true;
    notifyListeners();
    try {
      await database.voidSale(sale.id);
      statusMessage = '${sale.saleNumber} voided and stock restored.';
      await Future.wait([
        refreshInventory(notify: false),
        refreshSales(notify: false),
        refreshReports(notify: false),
        refreshAudit(notify: false),
      ]);
      notifyListeners();
    } finally {
      saleBusy = false;
      notifyListeners();
    }
  }

  Future<void> locateSku(String sku) async {
    final item = await database.findItemBySku(sku);
    section = AppSection.inventory;
    if (item == null) {
      statusMessage = 'Barcode not found: $sku';
      notifyListeners();
      return;
    }
    inventorySearch = item.sku;
    inventoryPageIndex = 0;
    inventoryPage = await database.getInventoryPage(search: item.sku, page: 0);
    selectedItem = item;
    statusMessage = "Barcode matched '${item.name}'.";
    notifyListeners();
  }

  Future<void> refreshReports({bool notify = true}) async {
    final results = await Future.wait<Object>([
      database.getKpis(),
      database.getCategorySummaries(),
      database.getLowStockThreats(),
    ]);
    kpis = results[0] as KpiSnapshot;
    categorySummaries = results[1] as List<CategorySummary>;
    lowStockThreats = results[2] as List<LowStockThreat>;
    if (notify) notifyListeners();
  }

  Future<void> importCsv() async {
    final result = await exports.importInventoryCsv();
    if (result == null) return;
    statusMessage = result.skippedDuplicates.isEmpty
        ? 'Imported ${result.imported} item(s) from CSV.'
        : 'Imported ${result.imported}; skipped ${result.skippedDuplicates.length} duplicate name(s).';
    await refreshCategories(notify: false);
    await _refreshAfterInventoryMutation();
  }

  Future<Uri?> exportInventoryCsv() async {
    final uri = await exports.exportInventoryCsv();
    if (uri != null) setStatus('Inventory CSV saved.');
    return uri;
  }

  Future<Uri?> exportInventoryPdf() async {
    final uri = await exports.exportInventoryPdf();
    if (uri != null) setStatus('PDF report saved.');
    return uri;
  }

  Future<void> refreshAudit({bool notify = true}) async {
    auditItemNames = await database.getAuditItemNames();
    auditPage = await database.getAuditPage(filter: auditFilter, page: auditPageIndex);
    final totalPages = auditTotalPages;
    if (auditPageIndex >= totalPages) {
      auditPageIndex = totalPages - 1;
      auditPage = await database.getAuditPage(filter: auditFilter, page: auditPageIndex);
    }
    if (notify) notifyListeners();
  }

  Future<void> setAuditFilter(AuditFilter filter) async {
    auditFilter = filter;
    auditPageIndex = 0;
    selectedLedgerEntry = null;
    await refreshAudit();
  }

  Future<void> clearAuditFilters() async {
    auditFilter = AuditFilter(
      dateFrom: DateTime.now().subtract(const Duration(days: 30)),
      dateTo: DateTime.now(),
    );
    auditPageIndex = 0;
    selectedLedgerEntry = null;
    await refreshAudit();
  }

  Future<void> auditPrev() async {
    if (auditPageIndex <= 0) return;
    auditPageIndex--;
    await refreshAudit();
  }

  Future<void> auditNext() async {
    if ((auditPageIndex + 1) * DatabaseService.auditPageSize >= auditPage.total) return;
    auditPageIndex++;
    await refreshAudit();
  }

  void selectLedgerEntry(LedgerEntry? entry) {
    selectedLedgerEntry = entry;
    notifyListeners();
  }

  Future<void> rollbackSelectedLedger() async {
    final entry = selectedLedgerEntry;
    if (entry == null) throw StateError('Select a ledger entry first.');
    await database.rollbackLedgerEntry(entry.ledgerId);
    statusMessage = 'Rollback reversal written for ledger #${entry.ledgerId}.';
    selectedLedgerEntry = null;
    await _refreshAfterInventoryMutation();
  }

  Future<Uri?> exportAuditCsv() async {
    final uri = await exports.exportAuditCsv(auditFilter);
    if (uri != null) setStatus('Audit ledger CSV saved.');
    return uri;
  }

  Future<Uri?> exportItemHistory(InventoryItem item) async {
    final uri = await exports.exportItemHistoryCsv(item.id, item.name);
    if (uri != null) setStatus("History for '${item.name}' exported.");
    return uri;
  }

  Future<void> refreshSuppliers({bool notify = true}) async {
    suppliers = await database.getSuppliers();
    if (selectedSupplier != null && !suppliers.any((s) => s.id == selectedSupplier!.id)) {
      selectedSupplier = null;
    }
    if (notify) notifyListeners();
  }

  void selectSupplier(SupplierRecord? supplier) {
    selectedSupplier = supplier;
    notifyListeners();
  }

  Future<void> saveSupplier({int? id, required String name, String email = '', String phone = '', String notes = ''}) async {
    await database.saveSupplier(id: id, name: name, email: email, phone: phone, notes: notes);
    statusMessage = "Supplier '$name' ${id == null ? 'added' : 'updated'}.";
    selectedSupplier = null;
    await refreshSuppliers();
  }

  Future<void> deleteSupplier(SupplierRecord supplier) async {
    await database.deleteSupplier(supplier.id);
    statusMessage = "Supplier '${supplier.name}' deleted.";
    selectedSupplier = null;
    await refreshSuppliers();
  }

  Future<void> addCategory(String name) async {
    await database.addCategory(name);
    statusMessage = "Category '$name' added.";
    await refreshCategories();
  }

  Future<void> removeCategory(String name) async {
    await database.removeCategory(name);
    statusMessage = "Category '$name' removed.";
    await refreshCategories();
  }

  void applyTheme(SmartStockTheme next) {
    theme = next;
    customAccent = null;
    statusMessage = 'Theme applied: ${next.label}';
    notifyListeners();
  }

  void setAccent(Color? color) {
    customAccent = color;
    statusMessage = color == null ? 'Custom accent reset.' : 'Custom accent applied.';
    notifyListeners();
  }

  Future<Uri?> backupDatabase() async {
    final uri = await exports.backupDatabase();
    if (uri != null) setStatus('Database backup saved.');
    return uri;
  }

  Future<bool> importLegacyDatabase() async {
    final restored = await exports.importLegacyDatabase();
    if (!restored) return false;
    inventoryPageIndex = 0;
    auditPageIndex = 0;
    selectedItem = null;
    selectedLedgerEntry = null;
    selectedSupplier = null;
    statusMessage = 'Legacy/plaintext SmartStock database imported.';
    await refreshAll();
    return true;
  }

  Future<void> resetInventory() async {
    await database.resetInventory();
    statusMessage = 'All inventory items were cleared. Categories were preserved.';
    await _refreshAfterInventoryMutation();
  }

  Future<String?> chooseSchedulerDirectory() async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Choose scheduled report folder');
    if (path != null) {
      schedulerOutputDirectory = path;
      notifyListeners();
    }
    return path;
  }

  void startScheduler({required int minutes, required ScheduledFormat format, required String directory}) {
    if (minutes < 5) throw ArgumentError('Interval must be at least 5 minutes.');
    if (directory.trim().isEmpty) throw ArgumentError('Choose an output folder first.');
    _scheduler?.cancel();
    schedulerIntervalMinutes = minutes;
    schedulerFormat = format;
    schedulerOutputDirectory = directory.trim();
    schedulerRunning = true;
    _scheduler = Timer.periodic(Duration(minutes: minutes), (_) => unawaited(_schedulerFire()));
    statusMessage = 'Scheduler started: ${format.label} every $minutes min.';
    notifyListeners();
  }

  void stopScheduler() {
    _scheduler?.cancel();
    _scheduler = null;
    schedulerRunning = false;
    statusMessage = 'Scheduler stopped.';
    notifyListeners();
  }

  Future<void> _schedulerFire() async {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    var wroteAny = false;
    try {
      if (schedulerFormat == ScheduledFormat.csvOnly || schedulerFormat == ScheduledFormat.csvAndPdf) {
        final items = await database.getAllInventory();
        final rows = <List<Object?>>[
          ['ItemID', 'SKU', 'ItemName', 'Category', 'Quantity', 'UnitPrice'],
          ...items.map((i) => [i.id, i.sku, i.name, i.category, i.quantity, i.unitPrice]),
        ];
        final bytes = Uint8List.fromList(utf8.encode(Csv().encode(rows)));
        wroteAny |= await writeScheduledFile(schedulerOutputDirectory, 'inventory_$stamp.csv', bytes);
      }
      if (schedulerFormat == ScheduledFormat.pdfOnly || schedulerFormat == ScheduledFormat.csvAndPdf) {
        final bytes = await exports.buildInventoryPdf(scheduled: true);
        wroteAny |= await writeScheduledFile(schedulerOutputDirectory, 'report_$stamp.pdf', bytes);
      }
      statusMessage = wroteAny
          ? 'Scheduled report generated: $stamp'
          : 'Scheduled reports require a desktop/mobile writable folder on this platform.';
    } catch (e) {
      statusMessage = 'Scheduled report failed: $e';
    }
    notifyListeners();
  }

  Future<void> shutdown() async {
    _scheduler?.cancel();
    _scheduler = null;
    try {
      await database.close(encrypt: true);
    } catch (_) {
      // Lifecycle teardown must not throw into the framework.
    }
  }

  @override
  void dispose() {
    _scheduler?.cancel();
    super.dispose();
  }
}
