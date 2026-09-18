import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common/sqlite_api.dart';

abstract interface class DatabaseKeyStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class SecureDatabaseKeyStore implements DatabaseKeyStore {
  const SecureDatabaseKeyStore();
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read(String name) => _storage.read(key: name);
  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}

class LegacyDatabaseKeyRequired implements Exception {
  @override
  String toString() =>
      'This older Flutter database needs its previous passphrase. '
      'Your database has not been changed.';
}

/// Encrypts cleanly closed databases with a random key held by platform storage.
/// The open SQLite database remains plaintext; this is not full-disk encryption.
class DatabaseCrypto {
  DatabaseCrypto(this.factory, this.dbPath, {DatabaseKeyStore? keyStore})
    : keyStore = keyStore ?? const SecureDatabaseKeyStore();

  final DatabaseFactory factory;
  final String dbPath;
  final DatabaseKeyStore keyStore;
  String get encryptedPath => '$dbPath.enc';
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _key;

  Future<SecretKey> _loadKey({required bool create}) async {
    final nameHash = await Sha256().hash(utf8.encode(dbPath));
    final name = 'smartstock.database.v2.${base64Url.encode(nameHash.bytes)}';
    final saved = await keyStore.read(name);
    if (saved != null) {
      final bytes = base64Decode(saved);
      if (bytes.length != 32)
        throw StateError(
          'Stored database key is invalid. No data was changed.',
        );
      return SecretKey(bytes);
    }
    if (!create) {
      throw StateError(
        'The encryption key is missing from this device. '
        'Restore a plaintext backup from the original installation; do not delete the encrypted database.',
      );
    }
    final key = await _cipher.newSecretKey();
    final encoded = base64Encode(await key.extractBytes());
    await keyStore.write(name, encoded);
    if (await keyStore.read(name) != encoded) {
      throw StateError(
        'Secure storage could not retain the database key. No database was changed.',
      );
    }
    return key;
  }

  Future<void> decryptIfNeeded({String? legacyPassphrase}) async {
    if (!await factory.databaseExists(encryptedPath)) {
      _key = await _loadKey(create: true);
      return;
    }
    if (await factory.databaseExists(dbPath)) {
      throw StateError(
        'Both plaintext and encrypted databases exist. '
        'Back up both files and resolve which is current before retrying. Neither was overwritten.',
      );
    }
    final payload = await factory.readDatabaseBytes(encryptedPath);
    if (payload.length < 32)
      throw StateError(
        'Encrypted database is truncated. Original file preserved.',
      );
    final format = String.fromCharCodes(payload.take(4));
    SecretKey decryptKey;
    if (format == 'SSG1') {
      if (legacyPassphrase == null || legacyPassphrase.isEmpty)
        throw LegacyDatabaseKeyRequired();
      decryptKey = SecretKey(
        (await Sha256().hash(utf8.encode(legacyPassphrase))).bytes,
      );
    } else if (format == 'SSG2') {
      decryptKey = await _loadKey(create: false);
    } else {
      throw StateError(
        'Unsupported encrypted database. Python Fernet files must first '
        'be opened and backed up by the PyQt app. Original file preserved.',
      );
    }
    final clear = await _cipher.decrypt(
      SecretBox(
        payload.sublist(32),
        nonce: payload.sublist(4, 16),
        mac: Mac(payload.sublist(16, 32)),
      ),
      secretKey: decryptKey,
    );
    if (clear.length < 16 ||
        String.fromCharCodes(clear.take(16)) != 'SQLite format 3\u0000') {
      throw StateError(
        'Decrypted data is not a SQLite database. Original file preserved.',
      );
    }
    _key = format == 'SSG2' ? decryptKey : await _loadKey(create: true);
    if (format == 'SSG1') {
      final backup = '$encryptedPath.legacy-backup';
      if (!await factory.databaseExists(backup)) {
        await factory.writeDatabaseBytes(backup, payload);
        if (!_same(await factory.readDatabaseBytes(backup), payload)) {
          throw StateError(
            'Legacy backup verification failed. Original file preserved.',
          );
        }
      }
    }
    await factory.writeDatabaseBytes(dbPath, Uint8List.fromList(clear));
    if (!_same(await factory.readDatabaseBytes(dbPath), clear)) {
      throw StateError(
        'Database recovery verification failed. Encrypted original preserved.',
      );
    }
    await factory.deleteDatabase(encryptedPath);
  }

  Future<void> encryptAndDeletePlaintext() async {
    final key = _key;
    if (key == null)
      throw StateError(
        'Database encryption was not initialized. Plaintext preserved.',
      );
    if (!await factory.databaseExists(dbPath)) return;
    if (await factory.databaseExists(encryptedPath)) {
      throw StateError(
        'An encrypted database already exists. Both files preserved.',
      );
    }
    final clear = await factory.readDatabaseBytes(dbPath);
    final box = await _cipher.encrypt(clear, secretKey: key);
    final out = BytesBuilder(copy: false)
      ..add(utf8.encode('SSG2'))
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    final payload = out.takeBytes();
    await factory.writeDatabaseBytes(encryptedPath, payload);
    if (!_same(await factory.readDatabaseBytes(encryptedPath), payload)) {
      throw StateError(
        'Encrypted backup verification failed. Plaintext preserved.',
      );
    }
    await factory.deleteDatabase(dbPath);
  }

  bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
