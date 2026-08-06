import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Future<void> saveAccessToken(String t) =>
      _storage.write(key: 'bb.at', value: t);
  Future<String?> getAccessToken() => _storage.read(key: 'bb.at');
  Future<void> saveRefreshToken(String t) =>
      _storage.write(key: 'bb.rt', value: t);
  Future<String?> getRefreshToken() => _storage.read(key: 'bb.rt');
  Future<void> saveRememberMe(bool v) =>
      _storage.write(key: 'bb.rm', value: v.toString());
  Future<bool> getRememberMe() async =>
      (await _storage.read(key: 'bb.rm')) == 'true';
  Future<void> clearSession() async {
    await _storage.delete(key: 'bb.at');
    await _storage.delete(key: 'bb.rt');
  }

  Future<void> clearAll() => _storage.deleteAll();
}
