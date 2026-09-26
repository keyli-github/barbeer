import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Encrypted, server- and user-scoped recovery records. Never persist PINs.
class OfflineStore {
  OfflineStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );
  static final instance = OfflineStore();
  final FlutterSecureStorage _storage;
  Future<void> _tail = Future.value();
  Future<void> _cacheTail = Future.value();

  static bool canQueue(String method, String path) {
    // Annulment payloads may contain a SUPERADMIN PIN; never stage them.
    if (RegExp(r'^/caja/[^/]+/movimientos/[^/]+/anular$').hasMatch(path)) {
      return false;
    }
    // Manual payroll recargos are unsafe to replay after an ambiguous outcome.
    if ((method == 'POST' &&
            RegExp(r'^/pagos/[^/]+/recargos$').hasMatch(path)) ||
        (method == 'DELETE' &&
            RegExp(r'^/pagos/recargos/[^/]+$').hasMatch(path))) {
      return false;
    }
    // Cash balance payouts must be completed against the active Caja session.
    if (method == 'POST' &&
        RegExp(r'^/cuentas/[^/]+/saldo-a-favor/pagos$').hasMatch(path)) {
      return false;
    }
    if (path == '/asistencia/marcar' ||
        path.endsWith('/stock') ||
        path.contains('/sin-luz') ||
        path.contains('/imagen')) {
      return false;
    }
    return RegExp(
          r'^/(productos|productos-internos|gastos-internos|pagos|categorias|inventario|compras|cuentas|etiquetas|turnos|asistencia|caja)(/|$)',
        ).hasMatch(path) &&
        !path.contains('/reporte/') &&
        ['POST', 'PATCH', 'PUT', 'DELETE'].contains(method);
  }

  static bool canCache(String path) =>
      RegExp(
        r'^/(productos|productos-internos|gastos-internos|pagos|categorias|inventario|compras|cuentas|etiquetas|turnos|asistencia|caja)(/|$)',
      ).hasMatch(path) &&
      !path.contains('qr-kiosco') &&
      !path.contains('/reporte/');

  Future<Map<String, dynamic>> stageCommand(
    String scope,
    String method,
    String path,
    dynamic data,
  ) async {
    Map<String, dynamic>? result;
    final task = _tail.then((_) async {
      final records = await _readSales(scope);
      final encoded = jsonEncode(data);
      final existing = records.where((record) {
        final payload = record['payload'] as Map;
        return record['status'] != 'SYNCED' &&
            payload['kind'] == 'HTTP_COMMAND' &&
            payload['method'] == method &&
            payload['path'] == path &&
            jsonEncode(payload['data']) == encoded;
      }).firstOrNull;
      result = existing == null
          ? {
              'idempotencyKey': const Uuid().v4(),
              'kind': 'HTTP_COMMAND',
              'method': method,
              'path': path,
              'data': jsonDecode(encoded),
            }
          : Map<String, dynamic>.from(existing['payload'] as Map);
      if (existing == null) {
        records.add({
          'id': result!['idempotencyKey'],
          'payload': result,
          'status': 'PENDING',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
        await _storage.write(
          key: 'bb.sales.$scope',
          value: jsonEncode(records),
        );
      }
    });
    _tail = task.catchError((_) {});
    await task;
    return result!;
  }

  Future<String?> _cacheKey(
    String path,
    Map<String, dynamic>? query,
    String? authorization,
  ) async {
    final token =
        authorization?.replaceFirst('Bearer ', '') ??
        await SecureStorageService.instance.getAccessToken();
    final owner = scopeForToken(token);
    if (owner == null) return null;
    final claims =
        jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(token!.split('.')[1])),
              ),
            )
            as Map;
    final permissions =
        (claims['permisos'] as List? ?? []).map((item) => '$item').toList()
          ..sort();
    final parameters = (query ?? {}).keys.toList()..sort();
    final signature = jsonEncode([
      path,
      {for (final key in parameters) key: query![key]},
      claims['rol'],
      claims['sedeId'],
      permissions,
    ]);
    return '$owner.${sha256.convert(utf8.encode(signature))}';
  }

  Future<dynamic> cached(
    String path,
    Map<String, dynamic>? query, {
    String? authorization,
  }) async {
    final key = await _cacheKey(path, query, authorization);
    if (key == null) return null;
    await _cacheTail;
    final raw = await _storage.read(key: 'bb.cache.$key');
    if (raw == null) return null;
    final entry = jsonDecode(raw) as Map;
    final saved = DateTime.parse(entry['savedAt'] as String);
    if (DateTime.now().toUtc().difference(saved) > const Duration(days: 7)) {
      return null;
    }
    return entry['data'];
  }

  Future<void> cache(
    String path,
    Map<String, dynamic>? query,
    dynamic data, {
    String? authorization,
  }) async {
    final key = await _cacheKey(path, query, authorization);
    if (key == null) return;
    final task = _cacheTail.then((_) async {
      const indexKey = 'bb.cache.index';
      final rawIndex = await _storage.read(key: indexKey);
      final keys = rawIndex == null
          ? <String>[]
          : (jsonDecode(rawIndex) as List).cast<String>();
      keys.remove(key);
      keys.add(key);
      while (keys.length > 120) {
        await _storage.delete(key: 'bb.cache.${keys.removeAt(0)}');
      }
      await _storage.write(
        key: 'bb.cache.$key',
        value: jsonEncode({
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
      await _storage.write(key: indexKey, value: jsonEncode(keys));
    });
    _cacheTail = task.catchError((_) {});
    await task;
  }

  Future<String?> scope() async {
    final token = await SecureStorageService.instance.getAccessToken();
    return scopeForToken(token);
  }

  static String? scopeForToken(String? token) {
    if (token == null) return null;
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      final userId = claims['sub'];
      if (userId == null) return null;
      return sha256
          .convert(utf8.encode('${ApiConstants.baseUrl}|$userId'))
          .toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> sales(String scope) async {
    await _tail;
    return _readSales(scope);
  }

  Future<List<Map<String, dynamic>>> _readSales(String scope) async {
    final raw = await _storage.read(key: 'bb.sales.$scope');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> record(
    String scope,
    Map<String, dynamic> payload,
    String status, {
    String? error,
  }) {
    final operation = _tail.then((_) async {
      final records = await _readSales(scope);
      final index = records.indexWhere(
        (item) => item['id'] == payload['idempotencyKey'],
      );
      final sanitized = Map<String, dynamic>.from(payload)
        ..remove('superadminPin');
      final previous = index < 0 ? null : records[index];
      final record = <String, dynamic>{
        'id': payload['idempotencyKey'],
        'payload': sanitized,
        'status': status,
        'createdAt':
            previous?['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
        'error': error,
      };
      if (index < 0) {
        records.add(record);
      } else {
        records[index] = record;
      }
      // Retain all unresolved requests; bound the completed history.
      final completed = records
          .where((item) => item['status'] == 'SYNCED')
          .toList();
      if (completed.length > 50) {
        final expired = completed
            .take(completed.length - 50)
            .map((item) => item['id'])
            .toSet();
        records.removeWhere((item) => expired.contains(item['id']));
      }
      await _storage.write(key: 'bb.sales.$scope', value: jsonEncode(records));
    });
    _tail = operation.catchError((_) {});
    return operation;
  }
}
