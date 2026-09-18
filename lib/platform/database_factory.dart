import 'package:sqflite_common/sqlite_api.dart';

import 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as impl;

class SmartStockDatabaseInfo {
  const SmartStockDatabaseInfo({required this.factory, required this.path});
  final DatabaseFactory factory;
  final String path;
}

Future<SmartStockDatabaseInfo> createSmartStockDatabaseFactory({
  required bool sandbox,
}) async {
  final factory = await impl.createFactory();
  final path = await impl.databasePath(factory, sandbox: sandbox);
  return SmartStockDatabaseInfo(factory: factory, path: path);
}
