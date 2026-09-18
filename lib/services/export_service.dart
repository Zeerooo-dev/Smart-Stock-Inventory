import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database_service.dart';
import '../models/models.dart';

class ExportService {
  ExportService(this.database);
  final DatabaseService database;

  String _safeCsvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isNotEmpty && '=+-@'.contains(text[0])) return "'$text";
    return text;
  }

  Future<Uri?> exportInventoryCsv({
    String fileName = 'inventory_report.csv',
  }) async {
    final items = await database.getAllInventory();
    final rows = <List<Object?>>[
      ['ItemID', 'SKU', 'ItemName', 'Category', 'Quantity', 'UnitPrice'],
      ...items.map(
        (i) => [
          i.id,
          i.sku,
          _safeCsvCell(i.name),
          i.category,
          i.quantity,
          i.unitPrice,
        ],
      ),
    ];
    final data = utf8.encode(Csv().encode(rows));
    return FilePicker.saveFile(
      dialogTitle: 'Export Inventory',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(data),
    );
  }

  Future<CsvImportResult?> importInventoryCsv() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import Inventory CSV',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = Csv().decode(utf8.decode(bytes));
    if (decoded.isEmpty)
      throw const FormatException('CSV file is empty or has no headers.');
    final headers = decoded.first.map((e) => e.toString().trim()).toList();
    const required = {'ItemName', 'Category', 'Quantity', 'UnitPrice'};
    final missing = required.where((h) => !headers.contains(h)).toList();
    if (missing.isNotEmpty) {
      throw FormatException(
        'Missing required headers: ${missing.join(', ')}. Required: ItemName, Category, Quantity, UnitPrice.',
      );
    }
    final rows = <Map<String, String>>[];
    for (final record in decoded.skip(1)) {
      if (record.every((cell) => cell.toString().trim().isEmpty)) continue;
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < record.length ? record[i].toString() : '';
      }
      rows.add(row);
    }
    return database.importInventoryRows(rows);
  }

  Future<Uri?> exportAuditCsv(AuditFilter filter) async {
    final entries = await database.getAllAuditEntries(filter);
    final rows = <List<Object?>>[
      [
        'Timestamp (UTC)',
        'Item Name',
        'SKU',
        'Change Type',
        'Delta Quantity',
        'Price Snapshot',
        'Running Balance',
      ],
      ...entries.map(
        (e) => [
          e.timestamp,
          _safeCsvCell(e.itemName),
          e.sku,
          e.changeType,
          e.deltaQuantity,
          e.priceSnapshot,
          e.runningBalance,
        ],
      ),
    ];
    final data = utf8.encode(Csv().encode(rows));
    return FilePicker.saveFile(
      dialogTitle: 'Export Audit Ledger',
      fileName: 'smartstock_audit_ledger.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(data),
    );
  }

  Future<Uri?> exportItemHistoryCsv(int itemId, String itemName) async {
    final entries = await database.getAllItemHistory(itemId);
    final safeName = itemName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final rows = <List<Object?>>[
      [
        'Timestamp (UTC)',
        'Change Type',
        'Delta Quantity',
        'Price Snapshot',
        'Running Balance',
      ],
      ...entries.map(
        (e) => [
          e.timestamp,
          e.changeType,
          e.deltaQuantity,
          e.priceSnapshot,
          e.runningBalance,
        ],
      ),
    ];
    final data = utf8.encode(Csv().encode(rows));
    return FilePicker.saveFile(
      dialogTitle: 'Export Item History',
      fileName: 'history_${safeName.isEmpty ? itemId : safeName}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(data),
    );
  }

  Future<Uint8List> buildInventoryPdf({bool scheduled = false}) async {
    final items = await database.getAllInventory();
    final kpis = await database.getKpis();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => [
          pw.Text(
            scheduled
                ? 'SmartStock — Scheduled Inventory Report'
                : 'SmartStock Inventory — Corporate Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('2563EB'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const [
              'ID',
              'SKU',
              'Item',
              'Category',
              'Qty',
              'Unit Price',
              'Value',
            ],
            data: [
              ...items.map(
                (i) => [
                  '#${i.id.toString().padLeft(5, '0')}',
                  i.sku,
                  i.name,
                  i.category,
                  i.quantity.toString(),
                  'PHP ${i.unitPrice.toStringAsFixed(2)}',
                  'PHP ${i.value.toStringAsFixed(2)}',
                ],
              ),
              [
                '',
                '',
                '',
                'TOTALS',
                '${kpis.totalQuantity}',
                '',
                'PHP ${kpis.totalValue.toStringAsFixed(2)}',
              ],
            ],
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('2563EB'),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uri?> exportInventoryPdf() async {
    final bytes = await buildInventoryPdf();
    return FilePicker.saveFile(
      dialogTitle: 'Export PDF Report',
      fileName: 'smartstock_report.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
  }

  Future<Uri?> backupDatabase() async {
    final bytes = await database.backupBytes();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return FilePicker.saveFile(
      dialogTitle: 'Save Backup As',
      fileName: 'smartstock_backup_$stamp.db',
      type: FileType.custom,
      allowedExtensions: ['db'],
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<bool> importLegacyDatabase() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import SmartStock SQLite Database',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    await database.restorePlaintextDatabase(bytes);
    return true;
  }
}
