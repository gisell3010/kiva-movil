import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile_final/pages/app.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/pages/auth/auth_page.dart';
import 'package:kiva_mobile_final/pages/auth/welcome_page.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_controller.dart';
import 'session_test.dart' as fixtures;

void main() {
  testWidgets('La sesión guardada abre el dashboard sin mostrar bienvenida', (
    tester,
  ) async {
    late AuthController auth;
    await tester.runAsync(() async {
      final store = fixtures.MemoryStore();
      final api = ApiClient(
        store: store,
        dio: Dio()
          ..httpClientAdapter = fixtures.Adapter((request) {
            if (request.path.startsWith('/auth/')) {
              return fixtures.reply(
                200,
                fixtures.payload,
                cookie: fixtures.sessionCookie,
              );
            }
            return fixtures.reply(200, {
              'groups_count': 2,
              'trips_count': 1,
              'total_expenses': '0',
            });
          }),
      );
      await api.authenticate('login', {});
      final restored = ApiClient(
        store: store,
        dio: Dio()
          ..httpClientAdapter = fixtures.Adapter((request) {
            if (request.path == '/auth/refresh') {
              return fixtures.reply(
                200,
                fixtures.payload,
                cookie: fixtures.sessionCookie,
              );
            }
            return fixtures.reply(200, {
              'groups_count': 2,
              'trips_count': 1,
              'total_expenses': '0',
            });
          }),
      );
      auth = AuthController(AuthRepository(restored));
      await auth.start();
    });
    await tester.pumpWidget(KivaApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana Pérez'), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(AuthPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  testWidgets(
    'El teclado envía el acceso y un error permite corregir los datos',
    (tester) async {
      final auth = RecordingAuth();
      final startup = auth.start();
      await tester.pump();
      await startup;
      await tester.pumpWidget(KivaApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'ana@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('password')),
        'example-password',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(auth.requests, 1);
      expect(auth.email, 'ana@example.com');
      expect(auth.password, 'example-password');
      expect(find.text('Revisa tu correo y contraseña.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('email')),
        'otra@example.com',
      );
      await tester.pumpAndSettle();
      expect(find.text('Revisa tu correo y contraseña.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets('Registro valida campos fuera de la vista y enfoca el primero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(
      AuthRepository(ApiClient(store: fixtures.MemoryStore())),
    );
    final startup = auth.start();
    await tester.pump();
    await startup;
    await tester.pumpWidget(KivaApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Completa este campo.'), findsNWidgets(2));
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    final first = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('first_name')),
        matching: find.byType(TextField),
      ),
    );
    expect(first.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });

  for (final size in [
    const Size(320, 568),
    const Size(800, 360),
    const Size(800, 1280),
  ]) {
    testWidgets('Bienvenida accesible en $size con texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = AuthController(
        AuthRepository(ApiClient(store: fixtures.MemoryStore())),
      );
      final startup = auth.start();
      await tester.pump();
      await startup;
      await tester.pumpWidget(KivaApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Crear una cuenta'));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Crear una cuenta'));
      await tester.tap(find.text('Crear una cuenta'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
}

class RecordingAuth extends AuthController {
  RecordingAuth()
    : super(AuthRepository(ApiClient(store: fixtures.MemoryStore())));
  int requests = 0;
  String? email;
  String? password;
  @override
  Future<void> submit({
    required String email,
    required String password,
    Json? registration,
  }) async {
    requests++;
    this.email = email;
    this.password = password;
    emit(state.copyWith(error: 'Revisa tu correo y contraseña.'));
  }
}
