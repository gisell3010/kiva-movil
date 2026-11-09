import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'config.dart';
import 'errors.dart';
import 'session_store.dart';

typedef Json = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    String baseUrl = ApiConfig.defaultUrl,
    required this.store,
    Dio? dio,
  }) : base = ApiConfig.validate(baseUrl),
       _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: base.toString(),
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 65),
      sendTimeout: const Duration(seconds: 40),
      followRedirects: false,
      headers: {'Accept': 'application/json', 'X-KIVA-CSRF': '1'},
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );
  }
  final Dio _dio;
  final Uri base;
  final SessionStore store;
  String? _access;
  String? _cookie;
  Future<Json>? _refreshing;
  int _epoch = 0;
  Future<void> _storageQueue = Future<void>.value();

  // Serializa escrituras para que un cierre invalide también renovaciones en curso.
  Future<void> _persist(int epoch, String? value) {
    final operation = _storageQueue.then((_) async {
      if (epoch != _epoch) return;
      if (value == null) {
        await store.clear();
      } else {
        await store.write(value);
      }
    });
    _storageQueue = operation.catchError((Object _) {});
    return operation;
  }

  void Function()? onSessionExpired;

  int? get sessionId {
    try {
      final part = _access!.split('.')[1];
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(part))),
      );
      return int.tryParse(payload['sid'].toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> restore() async {
    final saved = await store.read();
    if (saved == null) return;
    try {
      final data = jsonDecode(saved) as Json;
      final expiry = DateTime.parse(data['expires'] as String);
      final value = data['cookie'] as String;
      if (expiry.isAfter(DateTime.now()) &&
          RegExp(
            r'^(__Secure-kiva_refresh|kiva_refresh)=[A-Za-z0-9._-]+$',
          ).hasMatch(value)) {
        _cookie = value;
      } else {
        await _persist(_epoch, null);
      }
    } catch (_) {
      await _persist(_epoch, null);
    }
  }

  bool get hasRefreshSession => _cookie != null;

  Future<void> _saveCookie(Response<dynamic> response, int epoch) async {
    if (epoch != _epoch) return;
    for (final header in response.headers['set-cookie'] ?? <String>[]) {
      final cookie = Cookie.fromSetCookieValue(header);
      if (!{'__Secure-kiva_refresh', 'kiva_refresh'}.contains(cookie.name)) {
        continue;
      }
      if (cookie.path != '/api/auth' || !cookie.httpOnly) continue;
      if (cookie.domain != null && cookie.domain != base.host) continue;
      if (cookie.name.startsWith('__Secure-') && !cookie.secure) continue;
      if (cookie.value.isEmpty || cookie.maxAge == 0) {
        _cookie = null;
        await _persist(_epoch, null);
        continue;
      }
      final expiry = cookie.maxAge != null
          ? DateTime.now().toUtc().add(Duration(seconds: cookie.maxAge!))
          : cookie.expires;
      if (expiry == null || !expiry.isAfter(DateTime.now())) continue;
      final value = '${cookie.name}=${cookie.value}';
      await _persist(
        epoch,
        jsonEncode({
          'cookie': value,
          'expires': expiry.toUtc().toIso8601String(),
        }),
      );
      if (epoch == _epoch) _cookie = value;
    }
  }

  Future<Json> authenticate(String operation, Json data) async {
    final epoch = ++_epoch;
    _access = null;
    _cookie = null;
    await _persist(_epoch, null);
    final response = await _raw(
      'POST',
      '/auth/$operation',
      data: data,
      auth: false,
    );
    final result = Map<String, dynamic>.from(response.data as Map);
    await _saveCookie(response, epoch);
    if (epoch != _epoch || _cookie == null) {
      throw const AppFailure(
        'No pudimos guardar tu sesión. Inténtalo de nuevo.',
      );
    }
    _access = result['access_token'] as String;
    return result;
  }

  Future<Json> refresh() {
    if (_refreshing != null) return _refreshing!;
    final operation = _refresh();
    _refreshing = operation;
    return operation.whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
  }

  Future<Json> _refresh() async {
    final epoch = _epoch;
    if (_cookie == null) throw const AppFailure('Vuelve a iniciar sesión.');
    try {
      final response = await _raw('POST', '/auth/refresh', auth: false);
      final data = Map<String, dynamic>.from(response.data as Map);
      await _saveCookie(response, epoch);
      if (epoch != _epoch) throw const AppFailure('La sesión terminó.');
      _access = data['access_token'] as String;
      return data;
    } on DioException catch (error) {
      if (epoch == _epoch &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 403)) {
        await clearSession();
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _raw(
    String method,
    String path, {
    Object? data,
    Json? query,
    bool auth = true,
    ResponseType? responseType,
  }) async {
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains('://') ||
        path.contains('..')) {
      throw const AppFailure('No pudimos abrir este contenido.');
    }
    final headers = <String, dynamic>{};
    if (auth && _access != null) {
      headers['Authorization'] = 'Bearer ${_access!}';
    }
    // La cookie de renovación solo acompaña a las solicitudes de autenticación.
    if (path.startsWith('/auth/') && _cookie != null) {
      headers['Cookie'] = _cookie;
    }
    return _dio.request<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: Options(
        method: method,
        headers: headers,
        responseType: responseType,
      ),
    );
  }

  Future<dynamic> request(
    String method,
    String path, {
    Object? data,
    Json? query,
    bool auth = true,
    ResponseType? responseType,
  }) async {
    final epoch = _epoch;
    final attemptedToken = _access;
    try {
      final response = await _raw(
        method,
        path,
        data: data,
        query: query,
        auth: auth,
        responseType: responseType,
      );
      if (auth && epoch != _epoch) throw const AppFailure('La sesión terminó.');
      await _saveCookie(response, epoch);
      return response.data;
    } on DioException catch (error) {
      if (auth &&
          epoch == _epoch &&
          error.response?.statusCode == 401 &&
          _cookie != null) {
        if (attemptedToken == _access) await refresh();
        if (epoch != _epoch) rethrow;
        try {
          final retry = await _raw(
            method,
            path,
            data: data is FormData ? data.clone() : data,
            query: query,
            auth: auth,
            responseType: responseType,
          );
          if (epoch != _epoch) throw const AppFailure('La sesión terminó.');
          await _saveCookie(retry, epoch);
          return retry.data;
        } on DioException catch (retryError) {
          if (epoch == _epoch && retryError.response?.statusCode == 401) {
            await clearSession();
          }
          rethrow;
        }
      }
      final body = error.response?.data;
      final code = body is Map && body['error'] is Map
          ? body['error']['code']
          : null;
      if (auth &&
          epoch == _epoch &&
          (error.response?.statusCode == 401 || code == 'ACCOUNT_INACTIVE')) {
        await clearSession();
      }
      rethrow;
    }
  }

  Future<Json> get(String path, {Json? query}) async =>
      Map<String, dynamic>.from(
        await request('GET', path, query: query) as Map,
      );

  Future<Uint8List> bytes(String path, {Json? query}) async {
    final value = await request(
      'GET',
      path,
      query: query,
      responseType: ResponseType.bytes,
    );
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    throw const AppFailure('No pudimos cargar la imagen.');
  }

  Future<void> logout() async {
    try {
      await _raw('POST', '/auth/logout', auth: false);
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    ++_epoch;
    _access = null;
    _cookie = null;
    await _persist(_epoch, null);
    onSessionExpired?.call();
  }
}
