import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_community/excel_community.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database_service.dart';
import '../models/models.dart';

typedef SaveExport =
Future<Uri?> Function(String name, Uint8List bytes, String extension);

class _PdfTransactionRow {
  const _PdfTransactionRow({
    required this.cells,
    required this.changeType,
    required this.quantityDelta,
    required this.quantityAfter,
  });

  final List<String> cells;
  final String changeType;
  final num? quantityDelta;
  final num? quantityAfter;
}

class ExportService {
  ExportService(this.database, {SaveExport? save}) : _save = save ?? _saveFile;

  final SaveExport _save;
  final DatabaseService database;

  static final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static final NumberFormat _quantityFormat = NumberFormat('#,##0.##', 'en_US');

  // ---------------------------------------------------------------------------
  // PDF COLORS
  // ---------------------------------------------------------------------------

  static final PdfColor _headerBlue = PdfColor.fromHex('1F4E78');
  static final PdfColor _gridColor = PdfColor.fromHex('D9E2F3');
  static final PdfColor _greenText = PdfColor.fromHex('006100');
  static final PdfColor _redFill = PdfColor.fromHex('FFC7CE');
  static final PdfColor _redText = PdfColor.fromHex('9C0006');

  // ---------------------------------------------------------------------------
  // XLSX COLORS / FORMATS
  // ---------------------------------------------------------------------------

  static final xl.ExcelColor _xlsxHeaderBlue = xl.ExcelColor.fromHexString(
    '#1F4E78',
  );
  static final xl.ExcelColor _xlsxGrid = xl.ExcelColor.fromHexString('#D9E2F3');
  static final xl.ExcelColor _xlsxGreenText = xl.ExcelColor.fromHexString(
    '#006100',
  );
  static final xl.ExcelColor _xlsxRedFill = xl.ExcelColor.fromHexString(
    '#FFC7CE',
  );
  static final xl.ExcelColor _xlsxRedText = xl.ExcelColor.fromHexString(
    '#9C0006',
  );

  static final xl.CustomNumericNumFormat _xlsxMoneyFormat =
  xl.CustomNumericNumFormat(formatCode: '₱#,##0.00');

  static final xl.CustomNumericNumFormat _xlsxQuantityFormat =
  xl.CustomNumericNumFormat(formatCode: '#,##0.##');

  static final xl.CustomNumericNumFormat _xlsxQuantityChangeFormat =
  xl.CustomNumericNumFormat(formatCode: '+#,##0.##;-#,##0.##;0');

  // Exact transaction order requested for BOTH PDF and XLSX.
  static const transactionHeaders = [
    'Item',
    'SKU',
    'Unit Price',
    'Quantity Before',
    'Quantity Changed',
    'Quantity After',
    'Date/Time (UTC)',
    'Transaction Type',
    'Notes',
  ];

  static Future<Uri?> _saveFile(
      String name,
      Uint8List bytes,
      String extension,
      ) {
    String mimeType;

    switch (extension.toLowerCase()) {
      case 'pdf':
        mimeType = 'application/pdf';
        break;
      case 'xlsx':
        mimeType =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        break;
      default:
        mimeType = 'application/octet-stream';
    }

    return FilePicker.saveFile(
      dialogTitle: 'Export SmartStock Report',
      fileName: name,
      bytes: bytes,
      mimeType: mimeType,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
  }

  // ---------------------------------------------------------------------------
  // COMMON FORMAT HELPERS
  // ---------------------------------------------------------------------------

  num? _parseNumber(Object? value) {
    if (value == null) return null;
    if (value is num) return value;

    final normalized = value
        .toString()
        .trim()
        .replaceAll(',', '')
        .replaceAll('₱', '')
        .replaceAll(RegExp('PHP', caseSensitive: false), '')
        .trim();

    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  String _formatQuantity(Object? value, {bool showPlus = false}) {
    final number = _parseNumber(value);
    if (number == null) return value?.toString() ?? '';

    final formatted = _quantityFormat.format(number.abs());
    if (number < 0) return '-$formatted';
    if (showPlus && number > 0) return '+$formatted';
    return formatted;
  }

  String _formatPeso(Object? value) {
    final number = _parseNumber(value);
    if (number == null) return value?.toString() ?? '';
    return _moneyFormat.format(number);
  }

  String _normalizeImportedNumber(String value) {
    return value
        .trim()
        .replaceAll(',', '')
        .replaceAll('₱', '')
        .replaceAll(RegExp('PHP', caseSensitive: false), '')
        .trim();
  }

  List<String> transactionCells(LedgerEntry e) => [
    e.itemName,
    e.sku,
    _formatPeso(e.priceSnapshot),
    _formatQuantity(e.beforeText),
    _formatQuantity(e.changeText, showPlus: true),
    _formatQuantity(e.afterText),
    e.timestamp,
    e.changeType,
    e.notes,
  ];

  // ---------------------------------------------------------------------------
  // XLSX HELPERS
  // ---------------------------------------------------------------------------

  xl.Border _xlsxThinBorder() =>
      xl.Border(borderStyle: xl.BorderStyle.Thin, borderColorHex: _xlsxGrid);

  xl.CellStyle _xlsxHeaderStyle() => xl.CellStyle(
    bold: true,
    fontColorHex: xl.ExcelColor.white,
    backgroundColorHex: _xlsxHeaderBlue,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: xl.TextWrapping.WrapText,
    leftBorder: _xlsxThinBorder(),
    rightBorder: _xlsxThinBorder(),
    topBorder: _xlsxThinBorder(),
    bottomBorder: _xlsxThinBorder(),
  );

  xl.CellStyle _xlsxTextStyle({
    xl.ExcelColor? fontColor,
    bool bold = false,
    bool wrap = false,
    xl.ExcelColor? background,
  }) => xl.CellStyle(
    bold: bold,
    fontColorHex: fontColor ?? xl.ExcelColor.black,
    backgroundColorHex: background ?? xl.ExcelColor.none,
    horizontalAlign: xl.HorizontalAlign.Left,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: wrap ? xl.TextWrapping.WrapText : xl.TextWrapping.Clip,
    leftBorder: _xlsxThinBorder(),
    rightBorder: _xlsxThinBorder(),
    topBorder: _xlsxThinBorder(),
    bottomBorder: _xlsxThinBorder(),
  );

  xl.CellStyle _xlsxNumberStyle({
    required xl.NumFormat numberFormat,
    xl.ExcelColor? fontColor,
    bool bold = false,
    xl.ExcelColor? background,
  }) => xl.CellStyle(
    bold: bold,
    fontColorHex: fontColor ?? xl.ExcelColor.black,
    backgroundColorHex: background ?? xl.ExcelColor.none,
    horizontalAlign: xl.HorizontalAlign.Right,
    verticalAlign: xl.VerticalAlign.Center,
    leftBorder: _xlsxThinBorder(),
    rightBorder: _xlsxThinBorder(),
    topBorder: _xlsxThinBorder(),
    bottomBorder: _xlsxThinBorder(),
    numberFormat: numberFormat,
  );

  xl.CellValue _xlsxNumberValue(num value) {
    if (value == value.roundToDouble()) {
      return xl.IntCellValue(value.toInt());
    }
    return xl.DoubleCellValue(value.toDouble());
  }

  void _xlsxSetText(
      xl.Sheet sheet,
      int column,
      int row,
      String value, {
        xl.CellStyle? style,
      }) {
    sheet.updateCell(
      xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      xl.TextCellValue(value),
      cellStyle: style ?? _xlsxTextStyle(),
    );
  }

  void _xlsxSetNumber(
      xl.Sheet sheet,
      int column,
      int row,
      num value, {
        required xl.CellStyle style,
      }) {
    sheet.updateCell(
      xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      _xlsxNumberValue(value),
      cellStyle: style,
    );
  }

  void _xlsxWriteHeader(xl.Sheet sheet, List<String> headers) {
    for (var column = 0; column < headers.length; column++) {
      _xlsxSetText(
        sheet,
        column,
        0,
        headers[column],
        style: _xlsxHeaderStyle(),
      );
    }
    sheet.setRowHeight(0, 30);
    sheet.frozenRows = 1;
  }

  void _xlsxConfigureTransactionColumns(xl.Sheet sheet) {
    // Item, SKU, Unit Price, Qty Before, Qty Changed, Qty After,
    // Date/Time UTC, Transaction Type, Notes
    const widths = [28.0, 18.0, 16.0, 16.0, 17.0, 16.0, 23.0, 20.0, 42.0];

    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  void _xlsxWriteTransactionRows(
      xl.Sheet sheet,
      List<LedgerEntry> entries, {
        int startRow = 1,
      }) {
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final row = startRow + index;

      final price = _parseNumber(entry.priceSnapshot);
      final before = _parseNumber(entry.beforeText);
      final changed = _parseNumber(entry.changeText);
      final after = _parseNumber(entry.afterText);
      final type = entry.changeType.toLowerCase();

      // 0 - Item
      _xlsxSetText(
        sheet,
        0,
        row,
        entry.itemName,
        style: _xlsxTextStyle(wrap: true),
      );

      // 1 - SKU
      _xlsxSetText(sheet, 1, row, entry.sku);

      // 2 - Unit Price
      if (price != null) {
        _xlsxSetNumber(
          sheet,
          2,
          row,
          price,
          style: _xlsxNumberStyle(numberFormat: _xlsxMoneyFormat),
        );
      } else {
        _xlsxSetText(sheet, 2, row, entry.priceSnapshot.toString());
      }

      // 3 - Quantity Before
      if (before != null) {
        _xlsxSetNumber(
          sheet,
          3,
          row,
          before,
          style: _xlsxNumberStyle(numberFormat: _xlsxQuantityFormat),
        );
      } else {
        _xlsxSetText(sheet, 3, row, entry.beforeText);
      }

      // 4 - Quantity Changed
      // NO BACKGROUND HIGHLIGHT.
      // Added = green text, subtracted = red text.
      if (changed != null) {
        _xlsxSetNumber(
          sheet,
          4,
          row,
          changed,
          style: _xlsxNumberStyle(
            numberFormat: _xlsxQuantityChangeFormat,
            fontColor: changed > 0
                ? _xlsxGreenText
                : changed < 0
                ? _xlsxRedText
                : xl.ExcelColor.black,
          ),
        );
      } else {
        _xlsxSetText(sheet, 4, row, entry.changeText);
      }

      // 5 - Quantity After
      // THE ONLY DATA CELL THAT GETS A BACKGROUND HIGHLIGHT:
      // if Quantity After == 0, use the red fill.
      if (after != null) {
        final zeroStock = after == 0;
        _xlsxSetNumber(
          sheet,
          5,
          row,
          after,
          style: _xlsxNumberStyle(
            numberFormat: _xlsxQuantityFormat,
            background: zeroStock ? _xlsxRedFill : null,
            fontColor: zeroStock ? _xlsxRedText : null,
            bold: zeroStock,
          ),
        );
      } else {
        _xlsxSetText(sheet, 5, row, entry.afterText);
      }

      // 6 - Date/Time (UTC)
      _xlsxSetText(sheet, 6, row, entry.timestamp);

      // 7 - Transaction Type
      // NO BACKGROUND HIGHLIGHT.
      // Created = green text, Dispense = red text.
      final typeColor = type.contains('creat')
          ? _xlsxGreenText
          : type.contains('dispens')
          ? _xlsxRedText
          : xl.ExcelColor.black;

      _xlsxSetText(
        sheet,
        7,
        row,
        entry.changeType,
        style: _xlsxTextStyle(
          fontColor: typeColor,
          bold: type.contains('creat') || type.contains('dispens'),
        ),
      );

      // 8 - Notes
      _xlsxSetText(
        sheet,
        8,
        row,
        entry.notes,
        style: _xlsxTextStyle(wrap: true),
      );

      sheet.setRowHeight(row, 22);
    }
  }

  Uint8List _xlsxBytes(xl.Excel workbook) {
    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Unable to generate the XLSX workbook.');
    }
    return Uint8List.fromList(bytes);
  }

  // ---------------------------------------------------------------------------
  // INVENTORY XLSX
  // ---------------------------------------------------------------------------

  Future<Uint8List> buildInventoryXlsx() async {
    final items = await database.getAllInventory();
    final entries = await database.getReportTransactions();
    final kpis = await database.getKpis();

    final workbook = xl.Excel.createExcel();
    workbook.rename('Sheet1', 'Inventory');

    final inventory = workbook['Inventory'];
    final transactions = workbook['Transaction History'];

    const inventoryHeaders = [
      'ID',
      'SKU',
      'Item',
      'Category',
      'Quantity',
      'Unit Price',
      'Value',
    ];

    _xlsxWriteHeader(inventory, inventoryHeaders);

    const inventoryWidths = [10.0, 18.0, 28.0, 20.0, 14.0, 16.0, 18.0];
    for (var i = 0; i < inventoryWidths.length; i++) {
      inventory.setColumnWidth(i, inventoryWidths[i]);
    }

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final row = index + 1;
      final quantity = _parseNumber(item.quantity);
      final unitPrice = _parseNumber(item.unitPrice);
      final value = _parseNumber(item.value);

      _xlsxSetText(inventory, 0, row, '#${item.id.toString().padLeft(5, '0')}');
      _xlsxSetText(inventory, 1, row, item.sku);
      _xlsxSetText(
        inventory,
        2,
        row,
        item.name,
        style: _xlsxTextStyle(wrap: true),
      );
      _xlsxSetText(inventory, 3, row, item.category);

      if (quantity != null) {
        _xlsxSetNumber(
          inventory,
          4,
          row,
          quantity,
          style: _xlsxNumberStyle(numberFormat: _xlsxQuantityFormat),
        );
      } else {
        _xlsxSetText(inventory, 4, row, item.quantity.toString());
      }

      if (unitPrice != null) {
        _xlsxSetNumber(
          inventory,
          5,
          row,
          unitPrice,
          style: _xlsxNumberStyle(numberFormat: _xlsxMoneyFormat),
        );
      } else {
        _xlsxSetText(inventory, 5, row, item.unitPrice.toString());
      }

      if (value != null) {
        _xlsxSetNumber(
          inventory,
          6,
          row,
          value,
          style: _xlsxNumberStyle(numberFormat: _xlsxMoneyFormat),
        );
      } else {
        _xlsxSetText(inventory, 6, row, item.value.toString());
      }
    }

    // Inventory totals row. This is a report summary, not conditional formatting.
    final totalRow = items.length + 1;
    for (var column = 0; column < inventoryHeaders.length; column++) {
      final cell = inventory.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: totalRow),
      );
      cell.cellStyle = _xlsxTextStyle(bold: true);
    }

    _xlsxSetText(
      inventory,
      3,
      totalRow,
      'TOTALS',
      style: _xlsxTextStyle(bold: true),
    );

    final totalQuantity = _parseNumber(kpis.totalQuantity);
    if (totalQuantity != null) {
      _xlsxSetNumber(
        inventory,
        4,
        totalRow,
        totalQuantity,
        style: _xlsxNumberStyle(numberFormat: _xlsxQuantityFormat, bold: true),
      );
    }

    final totalValue = _parseNumber(kpis.totalValue);
    if (totalValue != null) {
      _xlsxSetNumber(
        inventory,
        6,
        totalRow,
        totalValue,
        style: _xlsxNumberStyle(numberFormat: _xlsxMoneyFormat, bold: true),
      );
    }

    // Transaction History uses the exact requested column order.
    _xlsxWriteHeader(transactions, transactionHeaders);
    _xlsxConfigureTransactionColumns(transactions);
    _xlsxWriteTransactionRows(transactions, entries);

    return _xlsxBytes(workbook);
  }

  Future<Uri?> exportInventoryXlsx({
    String fileName = 'inventory_report.xlsx',
  }) async {
    return _save(fileName, await buildInventoryXlsx(), 'xlsx');
  }

  // ---------------------------------------------------------------------------
  // AUDIT XLSX
  // ---------------------------------------------------------------------------

  Future<Uint8List> buildAuditXlsx(AuditFilter filter) async {
    final entries = await database.getAllAuditEntries(filter);
    final workbook = xl.Excel.createExcel();
    workbook.rename('Sheet1', 'Audit Ledger');

    final sheet = workbook['Audit Ledger'];
    _xlsxWriteHeader(sheet, transactionHeaders);
    _xlsxConfigureTransactionColumns(sheet);
    _xlsxWriteTransactionRows(sheet, entries);

    return _xlsxBytes(workbook);
  }

  Future<Uri?> exportAuditXlsx(AuditFilter filter) async {
    return _save(
      'smartstock_audit_ledger.xlsx',
      await buildAuditXlsx(filter),
      'xlsx',
    );
  }

  // ---------------------------------------------------------------------------
  // ITEM HISTORY XLSX
  // ---------------------------------------------------------------------------

  Future<Uint8List> buildItemHistoryXlsx(int itemId) async {
    final entries = await database.getAllItemHistory(itemId);
    final workbook = xl.Excel.createExcel();
    workbook.rename('Sheet1', 'Item History');

    final sheet = workbook['Item History'];
    _xlsxWriteHeader(sheet, transactionHeaders);
    _xlsxConfigureTransactionColumns(sheet);
    _xlsxWriteTransactionRows(sheet, entries);

    return _xlsxBytes(workbook);
  }

  Future<Uri?> exportItemHistoryXlsx(int itemId, String itemName) async {
    final safeName = itemName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();

    return _save(
      'history_${safeName.isEmpty ? itemId : safeName}.xlsx',
      await buildItemHistoryXlsx(itemId),
      'xlsx',
    );
  }

  // ---------------------------------------------------------------------------
  // INVENTORY IMPORT
  // ---------------------------------------------------------------------------

  Future<CsvImportResult?> importInventoryCsv() =>
      _pickInventoryFile(const ['csv']);

  Future<CsvImportResult?> importInventoryXlsx() =>
      _pickInventoryFile(const ['xlsx']);

  Future<CsvImportResult?> importInventoryFile() =>
      _pickInventoryFile(const ['csv', 'xlsx']);

  Future<CsvImportResult?> _pickInventoryFile(List<String> extensions) async {
    final file = await FilePicker.pickFile(
      dialogTitle: extensions.length == 1
          ? 'Import Inventory ${extensions.single.toUpperCase()}'
          : 'Import Inventory CSV/XLSX',
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (file == null) return null;
    return importInventoryBytes(
      await file.readAsBytes(),
      extension: file.name.toLowerCase().endsWith('.xlsx') ? 'xlsx' : 'csv',
    );
  }

  Future<CsvImportResult> importInventoryBytes(
      Uint8List bytes, {
        required String extension,
      }) async {
    final decoded = switch (extension.toLowerCase()) {
      'csv' => Csv().decode(utf8.decode(bytes)),
      'xlsx' => _inventoryXlsxRows(bytes),
      _ => throw FormatException('Unsupported inventory file: .$extension'),
    };

    if (decoded.isEmpty) {
      throw const FormatException('Inventory file is empty or has no headers.');
    }

    final headers = decoded.first.map((e) => e.toString().trim()).toList();
    const required = {'ItemName', 'Category', 'Quantity', 'UnitPrice'};
    final missing = required.where((h) => !headers.contains(h)).toList();

    if (missing.isNotEmpty) {
      throw FormatException(
        'Missing required headers: ${missing.join(', ')}. '
            'Required: ItemName, Category, Quantity, UnitPrice.',
      );
    }

    final rows = <Map<String, String>>[];

    for (final record in decoded.skip(1)) {
      if (record.every((cell) => cell.toString().trim().isEmpty)) continue;

      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < record.length ? record[i].toString() : '';
      }

      if (row['Record Type'] == 'Transaction') continue;

      if (row.containsKey('Quantity')) {
        row['Quantity'] = _normalizeImportedNumber(row['Quantity'] ?? '');
      }

      if (row.containsKey('UnitPrice')) {
        row['UnitPrice'] = _normalizeImportedNumber(row['UnitPrice'] ?? '');
      }

      rows.add(row);
    }

    return database.importInventoryRows(rows);
  }

  List<List<dynamic>> _inventoryXlsxRows(Uint8List bytes) {
    final workbook = xl.Excel.decodeBytes(bytes);
    xl.Sheet? sheet = workbook.tables['Inventory'];
    if (sheet == null) {
      for (final candidate in workbook.tables.values) {
        if (candidate.rows.isEmpty) continue;
        final headers = candidate.rows.first
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .toSet();
        if ((headers.contains('Item') || headers.contains('ItemName')) &&
            headers.contains('Category') &&
            headers.contains('Quantity') &&
            (headers.contains('Unit Price') || headers.contains('UnitPrice'))) {
          sheet = candidate;
          break;
        }
      }
    }
    if (sheet == null) {
      throw const FormatException('XLSX file has no inventory worksheet.');
    }
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
    if (rows.isEmpty) return rows;
    rows[0] = [
      for (final header in rows[0])
        switch (header.trim()) {
          'Item' => 'ItemName',
          'Unit Price' => 'UnitPrice',
          _ => header,
        },
    ];
    final nameColumn = rows[0].indexOf('ItemName');
    final categoryColumn = rows[0].indexOf('Category');
    if (nameColumn >= 0 && categoryColumn >= 0) {
      rows.removeWhere(
            (row) =>
        row.length > categoryColumn &&
            row.length > nameColumn &&
            row[nameColumn].trim().isEmpty &&
            row[categoryColumn].trim() == 'TOTALS',
      );
    }
    return rows;
  }

  // ---------------------------------------------------------------------------
  // INVENTORY PDF
  // ---------------------------------------------------------------------------

  Future<Uint8List> buildInventoryPdf({bool scheduled = false}) async {
    final items = await database.getAllInventory();
    final kpis = await database.getKpis();
    final entries = await database.getReportTransactions();
    final document = pw.Document(theme: await _pdfTheme());

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: items.length + 20,
        margin: const pw.EdgeInsets.all(30),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            scheduled
                ? 'SmartStock - Scheduled Inventory Report'
                : 'SmartStock Inventory - Corporate Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _headerBlue,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: _gridColor, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.7),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(0.9),
              5: pw.FlexColumnWidth(1.15),
              6: pw.FlexColumnWidth(1.25),
            },
            children: [
              _pdfHeaderRow(const [
                'ID',
                'SKU',
                'Item',
                'Category',
                'Qty',
                'Unit Price',
                'Value',
              ]),
              ...List.generate(items.length, (index) {
                final item = items[index];

                // No conditional background on the inventory quantity.
                // The requested red background is ONLY for transaction
                // "Quantity After" when that value is zero.
                return pw.TableRow(
                  children: [
                    _pdfCell(
                      '#${item.id.toString().padLeft(5, '0')}',
                      alignment: pw.Alignment.centerRight,
                    ),
                    _pdfCell(item.sku),
                    _pdfCell(item.name),
                    _pdfCell(item.category),
                    _pdfCell(
                      _formatQuantity(item.quantity),
                      alignment: pw.Alignment.centerRight,
                    ),
                    _pdfCell(
                      _formatPeso(item.unitPrice),
                      alignment: pw.Alignment.centerRight,
                    ),
                    _pdfCell(
                      _formatPeso(item.value),
                      alignment: pw.Alignment.centerRight,
                    ),
                  ],
                );
              }),
              pw.TableRow(
                children: [
                  _pdfCell(''),
                  _pdfCell(''),
                  _pdfCell(''),
                  _pdfCell('TOTALS', bold: true),
                  _pdfCell(
                    _formatQuantity(kpis.totalQuantity),
                    bold: true,
                    alignment: pw.Alignment.centerRight,
                  ),
                  _pdfCell(''),
                  _pdfCell(
                    _formatPeso(kpis.totalValue),
                    bold: true,
                    alignment: pw.Alignment.centerRight,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    _addTransactionPages(
      document,
      entries,
      title: 'SmartStock Transaction History',
    );

    return document.save();
  }

  Future<Uri?> exportInventoryPdf() async =>
      _save('smartstock_report.pdf', await buildInventoryPdf(), 'pdf');

  Future<pw.ThemeData> _pdfTheme() async => pw.ThemeData.withFont(
    base: pw.Font.ttf(
      await rootBundle.load('assets/fonts/Carlito-Regular.ttf'),
    ),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Carlito-Bold.ttf')),
  );

  // ---------------------------------------------------------------------------
  // AUDIT PDF
  // ---------------------------------------------------------------------------

  Future<Uint8List> buildAuditPdf(AuditFilter filter) async {
    final entries = await database.getAllAuditEntries(filter);
    final document = pw.Document(theme: await _pdfTheme());

    _addTransactionPages(
      document,
      entries,
      title: 'SmartStock Audit Report',
      subtitle:
      '${DateFormat('yyyy-MM-dd').format(filter.dateFrom)} to '
          '${DateFormat('yyyy-MM-dd').format(filter.dateTo)} (UTC)'
          ' | Item: ${filter.itemName ?? 'All'}'
          ' | Type: ${filter.changeType ?? 'All'}',
    );

    return document.save();
  }

  Future<Uri?> exportAuditPdf(AuditFilter filter) async =>
      _save('smartstock_audit_report.pdf', await buildAuditPdf(filter), 'pdf');

  // ---------------------------------------------------------------------------
  // PDF HELPERS
  // ---------------------------------------------------------------------------

  pw.TableRow _pdfHeaderRow(List<String> headers) {
    return pw.TableRow(
      repeat: true,
      decoration: pw.BoxDecoration(color: _headerBlue),
      children: headers
          .map(
            (header) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 6,
          ),
          child: pw.Text(
            header,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  pw.Widget _pdfCell(
      String text, {
        PdfColor? background,
        PdfColor? textColor,
        bool bold = false,
        pw.Alignment alignment = pw.Alignment.centerLeft,
        double fontSize = 8,
      }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: pw.BoxDecoration(color: background),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: textColor ?? PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  List<_PdfTransactionRow> _buildPdfTransactionRows(List<LedgerEntry> entries) {
    final rows = <_PdfTransactionRow>[];

    for (final entry in entries) {
      final cells = transactionCells(entry);

      // Order:
      // Item, SKU, Unit Price, Qty Before, Qty Changed, Qty After,
      // Date/Time UTC, Transaction Type, Notes
      const limits = [100, 50, 24, 20, 20, 20, 30, 24, 180];

      var remaining = cells.map((s) => s.runes.toList()).toList();
      var continuation = false;

      final quantityDelta = _parseNumber(entry.changeText);
      final quantityAfter = _parseNumber(entry.afterText);

      while (remaining.any((r) => r.isNotEmpty)) {
        final chunks = List.generate(cells.length, (i) {
          var count = 0;
          var lineBreaks = 0;

          while (count < remaining[i].length && count < limits[i]) {
            final rune = remaining[i][count++];
            if (rune == 10 && ++lineBreaks == 4) break;
          }

          final chunk = String.fromCharCodes(remaining[i].take(count));
          remaining[i] = remaining[i].skip(count).toList();

          return i == 0 && continuation && chunk.isEmpty
              ? '(ledger #${entry.ledgerId} continued)'
              : chunk;
        });

        rows.add(
          _PdfTransactionRow(
            cells: chunks,
            changeType: entry.changeType,
            quantityDelta: quantityDelta,
            quantityAfter: quantityAfter,
          ),
        );

        continuation = true;
      }
    }

    return rows;
  }

  void _addTransactionPages(
      pw.Document document,
      List<LedgerEntry> entries, {
        required String title,
        String? subtitle,
      }) {
    final rows = _buildPdfTransactionRows(entries);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        maxPages: rows.length + 20,
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _headerBlue,
              ),
            ),
            pw.Text(
              'Exported: '
                  '${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} '
                  '(local)',
              style: const pw.TextStyle(fontSize: 9),
            ),
            if (subtitle != null)
              pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          if (rows.isEmpty)
            pw.Text('No transactions in this report.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: _gridColor, width: 0.5),
              columnWidths: const {
                // Item
                0: pw.FlexColumnWidth(1.55),
                // SKU
                1: pw.FlexColumnWidth(1.05),
                // Unit Price
                2: pw.FlexColumnWidth(1.05),
                // Quantity Before
                3: pw.FlexColumnWidth(0.9),
                // Quantity Changed
                4: pw.FlexColumnWidth(0.95),
                // Quantity After
                5: pw.FlexColumnWidth(0.9),
                // Date/Time UTC
                6: pw.FlexColumnWidth(1.25),
                // Transaction Type
                7: pw.FlexColumnWidth(1.1),
                // Notes
                8: pw.FlexColumnWidth(1.9),
              },
              children: [
                _pdfHeaderRow(transactionHeaders),
                ...List.generate(rows.length, (rowIndex) {
                  final row = rows[rowIndex];
                  final type = row.changeType.toLowerCase();

                  return pw.TableRow(
                    children: List.generate(row.cells.length, (columnIndex) {
                      PdfColor? background;
                      var textColor = PdfColors.black;
                      var bold = false;

                      // Transaction Type (index 7):
                      // no background; Created = green text, Dispense = red text.
                      if (columnIndex == 7 &&
                          row.cells[columnIndex].isNotEmpty) {
                        if (type.contains('creat')) {
                          textColor = _greenText;
                          bold = true;
                        } else if (type.contains('dispens')) {
                          textColor = _redText;
                          bold = true;
                        }
                      }

                      // Quantity Changed (index 4):
                      // no background; added = green text, subtracted = red text.
                      if (columnIndex == 4 &&
                          row.cells[columnIndex].isNotEmpty) {
                        if (row.quantityDelta != null &&
                            row.quantityDelta! > 0) {
                          textColor = _greenText;
                          bold = true;
                        } else if (row.quantityDelta != null &&
                            row.quantityDelta! < 0) {
                          textColor = _redText;
                          bold = true;
                        }
                      }

                      // Quantity After (index 5):
                      // the ONLY transaction data cell with a conditional
                      // background. If it reaches 0, highlight red.
                      if (columnIndex == 5 &&
                          row.cells[columnIndex].isNotEmpty &&
                          row.quantityAfter == 0) {
                        background = _redFill;
                        textColor = _redText;
                        bold = true;
                      }

                      final numericColumn =
                          columnIndex >= 2 && columnIndex <= 5;

                      return _pdfCell(
                        row.cells[columnIndex],
                        background: background,
                        textColor: textColor,
                        bold: bold,
                        fontSize: 8,
                        alignment: numericColumn
                            ? pw.Alignment.centerRight
                            : pw.Alignment.centerLeft,
                      );
                    }),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATABASE BACKUP
  // ---------------------------------------------------------------------------

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
