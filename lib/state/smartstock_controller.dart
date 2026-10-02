import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../data/database_service.dart';
import '../models/models.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/database_crypto.dart';
import '../services/scheduled_report_writer.dart';

enum AppSection { inventory, reports, audit, suppliers, settings }

enum ScheduledFormat { xlsxOnly, pdfOnly, xlsxAndPdf }

extension ScheduledFormatLabel on ScheduledFormat {
  String get label => switch (this) {
    ScheduledFormat.xlsxOnly => 'XLSX only',
    ScheduledFormat.pdfOnly => 'PDF only',
    ScheduledFormat.xlsxAndPdf => 'Both XLSX and PDF',
  };
}

class SmartStockController extends ChangeNotifier {
  SmartStockController({
    this.sandbox = false,
    DatabaseService? database,
    ExportService? exports,
    NotificationService? notifications,
  }) : database = database ?? DatabaseService(),
        notifications = notifications ?? NotificationService() {
    this.exports = exports ?? ExportService(this.database);
    lowStockMonitor = LowStockMonitor(
      this.database.getAllInventory,
      this.notifications,
    );
  }

  final bool sandbox;
  final DatabaseService database;
  late final ExportService exports;
  final NotificationService notifications;
  late final LowStockMonitor lowStockMonitor;

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
  int schedulerIntervalDays = 1;
  ScheduledFormat schedulerFormat = ScheduledFormat.xlsxOnly;
  String schedulerOutputDirectory = '';

  Timer? _auditScheduler;
  bool auditSchedulerRunning = false;
  int auditSchedulerIntervalDays = 7;
  ScheduledFormat auditSchedulerFormat = ScheduledFormat.xlsxOnly;
  String auditSchedulerOutputDirectory = '';

  int get inventoryTotalPages {
    final pages = (inventoryPage.total / DatabaseService.inventoryPageSize)
        .ceil();
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
      await lowStockMonitor.start();
      startupError = null;
      statusMessage = sandbox
          ? 'Sandbox database loaded.'
          : 'SmartStock ready.';
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
      refreshReports(notify: false),
      refreshAudit(notify: false),
      refreshSuppliers(notify: false),
    ]);
    notifyListeners();
  }

  void goTo(AppSection next) {
    section = next;
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
    inventoryPage = await database.getInventoryPage(
      search: inventorySearch,
      page: inventoryPageIndex,
    );
    final totalPages = inventoryTotalPages;
    if (inventoryPageIndex >= totalPages) {
      inventoryPageIndex = totalPages - 1;
      inventoryPage = await database.getInventoryPage(
        search: inventorySearch,
        page: inventoryPageIndex,
      );
    }
    if (selectedItem != null) {
      final matching = inventoryPage.items.where(
            (i) => i.id == selectedItem!.id,
      );
      selectedItem = matching.isEmpty ? null : matching.first;
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
    if ((inventoryPageIndex + 1) * DatabaseService.inventoryPageSize >=
        inventoryPage.total) {
      return;
    }
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
    notifications.show(
      'Item Added Successfully',
      '$name was successfully added to inventory.',
    );
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

  Future<void> adjustStock(
      InventoryItem item,
      int amount, {
        required bool restock,
        String notes = '',
      }) async {
    await database.adjustStock(
      itemId: item.id,
      amount: amount,
      restock: restock,
      notes: notes,
    );
    statusMessage =
    '${restock ? 'Restocked' : 'Dispensed'} $amount unit(s) for \'${item.name}\'.';
    await _refreshAfterInventoryMutation();
  }

  Future<void> _refreshAfterInventoryMutation() async {
    await Future.wait([
      refreshInventory(notify: false),
      refreshReports(notify: false),
      refreshAudit(notify: false),
    ]);
    await lowStockMonitor.check();
    notifyListeners();
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

  Future<void> importInventory() =>
      _importInventoryWith(exports.importInventoryFile);

  Future<void> importInventoryCsv() =>
      _importInventoryWith(exports.importInventoryCsv);

  Future<void> importInventoryXlsx() =>
      _importInventoryWith(exports.importInventoryXlsx);

  Future<void> _importInventoryWith(
      Future<CsvImportResult?> Function() pickAndImport,
      ) async {
    final result = await pickAndImport();
    if (result == null) return;
    statusMessage = result.skippedDuplicates.isEmpty
        ? 'Imported ${result.imported} item(s).'
        : 'Imported ${result.imported}; skipped ${result.skippedDuplicates.length} duplicate name(s).';
    await refreshCategories(notify: false);
    await _refreshAfterInventoryMutation();
  }

  Future<Uri?> exportInventoryXlsx() async {
    final uri = await exports.exportInventoryXlsx();
    if (uri != null) setStatus('Inventory XLSX saved.');
    return uri;
  }

  Future<Uri?> exportInventoryPdf() async {
    final uri = await exports.exportInventoryPdf();
    if (uri != null) setStatus('PDF report saved.');
    return uri;
  }

  Future<void> refreshAudit({bool notify = true}) async {
    auditItemNames = await database.getAuditItemNames();
    auditPage = await database.getAuditPage(
      filter: auditFilter,
      page: auditPageIndex,
    );
    final totalPages = auditTotalPages;
    if (auditPageIndex >= totalPages) {
      auditPageIndex = totalPages - 1;
      auditPage = await database.getAuditPage(
        filter: auditFilter,
        page: auditPageIndex,
      );
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
    if ((auditPageIndex + 1) * DatabaseService.auditPageSize >= auditPage.total) {
      return;
    }
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

  Future<Uri?> exportAuditXlsx() async {
    final uri = await exports.exportAuditXlsx(auditFilter);
    if (uri != null) {
      setStatus('Audit ledger XLSX saved.');
      notifications.show(
        'Audit Export Successful',
        'Your audit XLSX report was exported successfully.',
      );
    }
    return uri;
  }

  Future<Uri?> exportAuditPdf() async {
    final uri = await exports.exportAuditPdf(auditFilter);
    if (uri != null) {
      setStatus('Audit PDF saved.');
      notifications.show(
        'Audit Export Successful',
        'Your audit PDF report was exported successfully.',
      );
    }
    return uri;
  }

  Future<Uri?> exportItemHistoryXlsx(InventoryItem item) async {
    final uri = await exports.exportItemHistoryXlsx(item.id, item.name);
    if (uri != null) setStatus("XLSX history for '${item.name}' saved.");
    return uri;
  }

  Future<void> refreshSuppliers({bool notify = true}) async {
    suppliers = await database.getSuppliers();
    if (selectedSupplier != null &&
        !suppliers.any((s) => s.id == selectedSupplier!.id)) {
      selectedSupplier = null;
    }
    if (notify) notifyListeners();
  }

  void selectSupplier(SupplierRecord? supplier) {
    selectedSupplier = supplier;
    notifyListeners();
  }

  Future<void> saveSupplier({
    int? id,
    required String name,
    String email = '',
    String phone = '',
    String notes = '',
  }) async {
    await database.saveSupplier(
      id: id,
      name: name,
      email: email,
      phone: phone,
      notes: notes,
    );
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
    statusMessage = color == null
        ? 'Custom accent reset.'
        : 'Custom accent applied.';
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
    statusMessage =
    'All inventory items were cleared. Categories were preserved.';
    await _refreshAfterInventoryMutation();
  }

  Future<String?> chooseSchedulerDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose scheduled report folder',
    );
    if (path != null) {
      schedulerOutputDirectory = path;
      notifyListeners();
    }
    return path;
  }

  Future<String?> chooseAuditSchedulerDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose scheduled Audit Log folder',
    );
    if (path != null) {
      auditSchedulerOutputDirectory = path;
      notifyListeners();
    }
    return path;
  }

  void startScheduler({
    required int days,
    required ScheduledFormat format,
    required String directory,
  }) {
    if (days < 1) {
      throw ArgumentError('Interval must be at least 1 day.');
    }
    if (directory.trim().isEmpty) {
      throw ArgumentError('Choose an output folder first.');
    }
    _scheduler?.cancel();
    schedulerIntervalDays = days;
    schedulerFormat = format;
    schedulerOutputDirectory = directory.trim();
    schedulerRunning = true;
    _scheduler = Timer.periodic(
      Duration(days: days),
          (_) => unawaited(_schedulerFire()),
    );
    statusMessage =
    'Scheduler started: ${format.label} every $days day(s).';
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
      if (schedulerFormat == ScheduledFormat.xlsxOnly ||
          schedulerFormat == ScheduledFormat.xlsxAndPdf) {
        final bytes = await exports.buildInventoryXlsx();
        wroteAny |= await writeScheduledFile(
          schedulerOutputDirectory,
          'inventory_$stamp.xlsx',
          bytes,
        );
      }
      if (schedulerFormat == ScheduledFormat.pdfOnly ||
          schedulerFormat == ScheduledFormat.xlsxAndPdf) {
        final bytes = await exports.buildInventoryPdf(scheduled: true);
        wroteAny |= await writeScheduledFile(
          schedulerOutputDirectory,
          'report_$stamp.pdf',
          bytes,
        );
      }
      statusMessage = wroteAny
          ? 'Scheduled report generated (${schedulerFormat.label}): $stamp'
          : 'Scheduled reports require a desktop/mobile writable folder on this platform.';
    } catch (e) {
      statusMessage = 'Scheduled report failed: $e';
    }
    notifyListeners();
  }

  void startAuditScheduler({
    required int days,
    required ScheduledFormat format,
    required String directory,
  }) {
    if (days < 1) {
      throw ArgumentError('Interval must be at least 1 day.');
    }
    if (directory.trim().isEmpty) {
      throw ArgumentError('Choose an output folder first.');
    }
    _auditScheduler?.cancel();
    auditSchedulerIntervalDays = days;
    auditSchedulerFormat = format;
    auditSchedulerOutputDirectory = directory.trim();
    auditSchedulerRunning = true;
    _auditScheduler = Timer.periodic(
      Duration(days: days),
          (_) => unawaited(_auditSchedulerFire()),
    );
    statusMessage =
    'Audit scheduler started: ${format.label} every $days day(s).';
    notifyListeners();
  }

  void stopAuditScheduler() {
    _auditScheduler?.cancel();
    _auditScheduler = null;
    auditSchedulerRunning = false;
    statusMessage = 'Audit scheduler stopped.';
    notifyListeners();
  }

  Future<void> _auditSchedulerFire() async {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    var wroteAny = false;
    try {
      if (auditSchedulerFormat == ScheduledFormat.xlsxOnly ||
          auditSchedulerFormat == ScheduledFormat.xlsxAndPdf) {
        final bytes = await exports.buildAuditXlsx(auditFilter);
        wroteAny |= await writeScheduledFile(
          auditSchedulerOutputDirectory,
          'audit_$stamp.xlsx',
          bytes,
        );
      }
      if (auditSchedulerFormat == ScheduledFormat.pdfOnly ||
          auditSchedulerFormat == ScheduledFormat.xlsxAndPdf) {
        final bytes = await exports.buildAuditPdf(auditFilter);
        wroteAny |= await writeScheduledFile(
          auditSchedulerOutputDirectory,
          'audit_$stamp.pdf',
          bytes,
        );
      }
      statusMessage = wroteAny
          ? 'Scheduled Audit Log generated (${auditSchedulerFormat.label}): $stamp'
          : 'Scheduled Audit Log exports require a writable folder on this platform.';
      if (wroteAny) {
        notifications.show(
          'Scheduled Audit Export Successful',
          'Your scheduled Audit Log export was saved successfully.',
        );
      }
    } catch (e) {
      statusMessage = 'Scheduled Audit Log export failed: $e';
    }
    notifyListeners();
  }

  Future<void> shutdown() async {
    lowStockMonitor.dispose();
    _scheduler?.cancel();
    _scheduler = null;
    _auditScheduler?.cancel();
    _auditScheduler = null;
    try {
      await database.close(encrypt: true);
    } catch (_) {
      // Lifecycle teardown must not throw into the framework.
    }
  }

  @override
  void dispose() {
    lowStockMonitor.dispose();
    _scheduler?.cancel();
    _auditScheduler?.cancel();
    super.dispose();
  }
}
