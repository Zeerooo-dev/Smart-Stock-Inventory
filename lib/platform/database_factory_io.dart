import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as native;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseFactory> createFactory() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  // Android, iOS, and macOS use the native sqflite implementation.
  return native.databaseFactory;
}

Future<String> databasePath(DatabaseFactory factory, {required bool sandbox}) async {
  final dir = await getApplicationSupportDirectory();
  final smartStockDir = Directory(p.join(dir.path, 'SmartStock'));
  if (!await smartStockDir.exists()) {
    await smartStockDir.create(recursive: true);
  }
  return p.join(
    smartStockDir.path,
    sandbox ? 'smartstock_sandbox.db' : 'smartstock.db',
  );
}
