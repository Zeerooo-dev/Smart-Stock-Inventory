import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartstock_flutter/services/database_crypto.dart';

class MemoryKeys implements DatabaseKeyStore {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async {
    if (failWrites) throw StateError('Simulated unavailable secure storage');
    values[name] = value;
  }
}

void main() {
  late Directory temp;
  late String path;
  late MemoryKeys keys;
  final factory = databaseFactoryFfi;
  late Uint8List original;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('smartstock-crypto-test-');
    path = '${temp.path}/inventory.db';
    keys = MemoryKeys();
    final db = await factory.openDatabase(path);
    await db.execute('CREATE TABLE inventory (name TEXT)');
    await db.insert('inventory', {'name': 'Preserve this record'});
    await db.close();
    original = await factory.readDatabaseBytes(path);
  });
  tearDown(() async => temp.delete(recursive: true));

  Future<Uint8List> makeLegacy() async {
    final cipher = AesGcm.with256bits();
    final key = SecretKey(
      (await Sha256().hash(utf8.encode('test-only-passphrase'))).bytes,
    );
    final box = await cipher.encrypt(original, secretKey: key);
    final payload = Uint8List.fromList([
      ...utf8.encode('SSG1'),
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
    await factory.writeDatabaseBytes('$path.enc', payload);
    await factory.deleteDatabase(path);
    return payload;
  }

  test('new key round-trip survives a fresh crypto instance', () async {
    final crypto = DatabaseCrypto(factory, path, keyStore: keys);
    await crypto.decryptIfNeeded();
    await crypto.encryptAndDeletePlaintext();
    expect(await factory.databaseExists(path), isFalse);
    expect(
      String.fromCharCodes(
        (await factory.readDatabaseBytes('$path.enc')).take(4),
      ),
      'SSG2',
    );
    await DatabaseCrypto(factory, path, keyStore: keys).decryptIfNeeded();
    expect(await factory.readDatabaseBytes(path), original);
    expect(await factory.databaseExists('$path.enc'), isFalse);
  });

  test(
    'missing key preserves ciphertext and creates no replacement key',
    () async {
      final crypto = DatabaseCrypto(factory, path, keyStore: keys);
      await crypto.decryptIfNeeded();
      await crypto.encryptAndDeletePlaintext();
      final encrypted = await factory.readDatabaseBytes('$path.enc');
      keys.values.clear();
      await expectLater(
        DatabaseCrypto(factory, path, keyStore: keys).decryptIfNeeded(),
        throwsStateError,
      );
      expect(await factory.readDatabaseBytes('$path.enc'), encrypted);
      expect(await factory.databaseExists(path), isFalse);
      expect(keys.values, isEmpty);
    },
  );

  test(
    'legacy unlock requires a passphrase and wrong passphrase preserves data',
    () async {
      final encrypted = await makeLegacy();
      final crypto = DatabaseCrypto(factory, path, keyStore: keys);
      await expectLater(
        crypto.decryptIfNeeded(),
        throwsA(isA<LegacyDatabaseKeyRequired>()),
      );
      await expectLater(
        crypto.decryptIfNeeded(legacyPassphrase: 'incorrect-test-key'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(await factory.readDatabaseBytes('$path.enc'), encrypted);
      expect(await factory.databaseExists(path), isFalse);
      expect(keys.values, isEmpty);
    },
  );

  test(
    'legacy migration keeps recovery copy and next encryption uses random key',
    () async {
      final encrypted = await makeLegacy();
      final crypto = DatabaseCrypto(factory, path, keyStore: keys);
      await crypto.decryptIfNeeded(legacyPassphrase: 'test-only-passphrase');
      expect(await factory.readDatabaseBytes(path), original);
      expect(
        await factory.readDatabaseBytes('$path.enc.legacy-backup'),
        encrypted,
      );
      await crypto.encryptAndDeletePlaintext();
      await DatabaseCrypto(factory, path, keyStore: keys).decryptIfNeeded();
      expect(await factory.readDatabaseBytes(path), original);
    },
  );

  test(
    'secure storage failure during legacy migration leaves original intact',
    () async {
      final encrypted = await makeLegacy();
      keys.failWrites = true;
      await expectLater(
        DatabaseCrypto(
          factory,
          path,
          keyStore: keys,
        ).decryptIfNeeded(legacyPassphrase: 'test-only-passphrase'),
        throwsStateError,
      );
      expect(await factory.readDatabaseBytes('$path.enc'), encrypted);
      expect(await factory.databaseExists(path), isFalse);
    },
  );

  test(
    'both plaintext and ciphertext are preserved when recovery is ambiguous',
    () async {
      final encrypted = await makeLegacy();
      await factory.writeDatabaseBytes(path, original);
      await expectLater(
        DatabaseCrypto(
          factory,
          path,
          keyStore: keys,
        ).decryptIfNeeded(legacyPassphrase: 'test-only-passphrase'),
        throwsStateError,
      );
      expect(await factory.readDatabaseBytes('$path.enc'), encrypted);
      expect(await factory.readDatabaseBytes(path), original);
    },
  );

  test(
    'failed initialization cannot encrypt or delete a plaintext database',
    () async {
      final crypto = DatabaseCrypto(factory, path, keyStore: keys);
      keys.failWrites = true;
      await expectLater(crypto.decryptIfNeeded(), throwsStateError);
      await expectLater(crypto.encryptAndDeletePlaintext(), throwsStateError);
      expect(await factory.readDatabaseBytes(path), original);
      expect(await factory.databaseExists('$path.enc'), isFalse);
    },
  );
}
