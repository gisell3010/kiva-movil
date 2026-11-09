import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/config.dart';
import 'package:kiva_mobile_final/services/errors.dart';
import 'package:kiva_mobile_final/services/session_store.dart';
import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/services/validators.dart';

class MemoryStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody reply(int status, Object data, {String? cookie}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        'content-type': ['application/json'],
        if (cookie != null) 'set-cookie': [cookie],
      },
    );
const sessionCookie =
    '__Secure-kiva_refresh=refresh-one; Path=/api/auth; Max-Age=3600; Secure; HttpOnly; SameSite=Lax';
const payload = {
  'access_token': 'access-one',
  'expires_in': 900,
  'token_type': 'bearer',
  'user': {
    'id': 1,
    'full_name': 'Ana Pérez',
    'username': 'ana',
    'email': 'ana@example.com',
    'role': 'USER',
    'status': 'ACTIVE',
    'profile_image': null,
  },
};

void main() {
  test('La configuración de producción exige HTTPS sin credenciales', () {
    expect(
      ApiConfig.validate('https://kiva-api.onrender.com/api').path,
      '/api',
    );
    for (final url in [
      'http://localhost:8000/api',
      'https://a:b@api.example.com/api',
      'https://api.example.com/api?token=x',
      'https://api.example.com/other',
    ]) {
      expect(() => ApiConfig.validate(url), throwsFormatException);
    }
  });
  test('Registro respeta límites y normalización de usuario', () {
    expect(Validators.password('123456789', registration: true), isNotNull);
    expect(Validators.password('a' * 129, registration: true), isNotNull);
    expect(Validators.username(' ANA.PEREZ '), isNull);
    expect(Validators.email('correo sin arroba'), isNotNull);
  });
  test('El correo descarta puntos consecutivos y dominios inválidos', () {
    for (final invalid in [
      'ana..perez@gmail.com',
      'ana@gmail..com',
      '.ana@gmail.com',
      'ana.@gmail.com',
      'ana@-gmail.com',
      'ana@gmail.c',
      'ana@@gmail.com',
    ]) {
      expect(Validators.email(invalid), isNotNull, reason: invalid);
    }
    expect(Validators.email('ana+viajes@sub.gmail.com'), isNull);
    expect(Validators.email('maria.perez@gmail.com'), isNull);
  });

  test('Nombres reales y mínimos de soporte', () {
    for (final valid in [
      'María José',
      'Jean-Paul',
      "O'Connor",
      'D’Arcy',
      'J. R. R. Tolkien',
      'Á',
    ]) {
      expect(Validators.personName(valid, max: 120), isNull, reason: valid);
    }
    expect(Validators.personName('1234'), isNotNull);
    expect(Validators.personName('...'), isNotNull);
    expect(Validators.personName('Ana.. María'), isNotNull);
    expect(Validators.personName('   ', optional: true), isNull);
    expect(Validators.requiredText('Ok', min: 5, max: 150), isNotNull);
    expect(Validators.requiredText('No funciona', min: 10, max: 1000), isNull);
    expect(Validators.requiredText('Sí', min: 2, max: 1000), isNull);
    expect(Validators.reportId('2147483648'), isNotNull);
    expect(Validators.reportId('25'), isNull);
  });

  test('Un rol desconocido no recibe acceso', () {
    expect(
      () => Account.fromJson({
        ...payload['user'] as Map<String, dynamic>,
        'role': 'ROOT',
      }),
      throwsFormatException,
    );
  });
  test('Los errores nunca revelan contenido interno del servidor', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/secret'),
      response: Response(
        requestOptions: RequestOptions(path: '/secret'),
        statusCode: 500,
        data: {'detail': 'password=secret postgres://internal'},
      ),
    );
    expect(friendlyError(error), isNot(contains('secret')));
    expect(friendlyError(error), isNot(contains('500')));
  });
  test(
    'Persiste solo la cookie y no la contraseña ni el access token',
    () async {
      final store = MemoryStore();
      final dio = Dio()
        ..httpClientAdapter = Adapter((request) {
          expect(request.headers['X-KIVA-CSRF'], '1');
          return reply(200, payload, cookie: sessionCookie);
        });
      final api = ApiClient(store: store, dio: dio);
      await api.authenticate('login', {
        'email': 'ana@example.com',
        'password': 'not-stored',
      });
      expect(store.value, contains('refresh-one'));
      expect(store.value, isNot(contains('access-one')));
      expect(store.value, isNot(contains('not-stored')));
    },
  );
  test(
    'Recupera la sesión tras reinicio y respeta el alcance de la cookie',
    () async {
      final store = MemoryStore();
      final first = ApiClient(
        store: store,
        dio: Dio()
          ..httpClientAdapter = Adapter(
            (_) => reply(200, payload, cookie: sessionCookie),
          ),
      );
      await first.authenticate('login', {});
      final second = ApiClient(
        store: store,
        dio: Dio()
          ..httpClientAdapter = Adapter((request) {
            if (request.path == '/auth/refresh') {
              expect(request.headers['Cookie'], contains('refresh-one'));
              return reply(
                200,
                payload,
                cookie: sessionCookie.replaceAll('refresh-one', 'refresh-two'),
              );
            }
            expect(request.headers['Cookie'], isNull);
            expect(request.headers['Authorization'], 'Bearer access-one');
            return reply(200, {'groups_count': 2});
          }),
      );
      await second.restore();
      await second.refresh();
      expect((await second.get('/dashboard'))['groups_count'], 2);
      expect(store.value, contains('refresh-two'));
    },
  );
  test('Varias respuestas 401 comparten una sola renovación', () async {
    final store = MemoryStore();
    var refreshes = 0;
    final api = ApiClient(
      store: store,
      dio: Dio()
        ..httpClientAdapter = Adapter((request) async {
          if (request.path == '/auth/login') {
            return reply(200, payload, cookie: sessionCookie);
          }
          if (request.path == '/auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return reply(200, {
              ...payload,
              'access_token': 'access-two',
            }, cookie: sessionCookie);
          }
          if (request.headers['Authorization'] == 'Bearer access-one') {
            return reply(401, {});
          }
          return reply(200, {'ok': true});
        }),
    );
    await api.authenticate('login', {});
    final results = await Future.wait([
      api.get('/dashboard'),
      api.get('/users/me'),
    ]);
    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(refreshes, 1);
  });
  test('Una renovación tardía no vuelve a abrir una sesión cerrada', () async {
    final store = MemoryStore();
    final gate = Completer<void>();
    final api = ApiClient(
      store: store,
      dio: Dio()
        ..httpClientAdapter = Adapter((request) async {
          if (request.path == '/auth/refresh') await gate.future;
          return reply(200, payload, cookie: sessionCookie);
        }),
    );
    await api.authenticate('login', {});
    final renewal = api.refresh();
    final expectation = expectLater(renewal, throwsA(isA<AppFailure>()));
    await api.clearSession();
    gate.complete();
    await expectation;
    expect(store.value, isNull);
    expect(api.hasRefreshSession, isFalse);
  });
  test('Una sesión revocada se elimina y avisa a la navegación', () async {
    final store = MemoryStore();
    var expired = false;
    final api = ApiClient(
      store: store,
      dio: Dio()
        ..httpClientAdapter = Adapter(
          (request) => request.path == '/auth/login'
              ? reply(200, payload, cookie: sessionCookie)
              : reply(401, {}),
        ),
    );
    api.onSessionExpired = () => expired = true;
    await api.authenticate('login', {});
    await expectLater(api.get('/dashboard'), throwsA(isA<DioException>()));
    expect(expired, isTrue);
    expect(store.value, isNull);
  });
  test('Una desconexión conserva la sesión para reintentar', () async {
    final store = MemoryStore();
    final api = ApiClient(
      store: store,
      dio: Dio()
        ..httpClientAdapter = Adapter((request) {
          if (request.path == '/auth/login') {
            return reply(200, payload, cookie: sessionCookie);
          }
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }),
    );
    await api.authenticate('login', {});
    await expectLater(api.refresh(), throwsA(isA<DioException>()));
    expect(api.hasRefreshSession, isTrue);
    expect(store.value, isNotNull);
  });
}
