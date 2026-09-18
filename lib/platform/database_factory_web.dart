import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<DatabaseFactory> createFactory() async => databaseFactoryFfiWeb;

Future<String> databasePath(DatabaseFactory factory, {required bool sandbox}) async =>
    sandbox ? 'smartstock_sandbox.db' : 'smartstock.db';
