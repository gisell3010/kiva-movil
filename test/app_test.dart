import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile/app.dart';
import 'package:kiva_mobile/core/api_client.dart';
import 'package:kiva_mobile/features/auth/repositories/auth_repository.dart';
import 'package:kiva_mobile/features/auth/state/auth_controller.dart';
import 'session_test.dart' as fixtures;

void main() {
  testWidgets(
    'El inicio sin sesión conduce al acceso y valida antes de enviar',
    (tester) async {
      var requests = 0;
      final api = ApiClient(
        store: fixtures.MemoryStore(),
        dio: Dio()
          ..httpClientAdapter = fixtures.Adapter((_) {
            requests++;
            return fixtures.reply(200, {});
          }),
      );
      final auth = AuthController(AuthRepository(api));
      await auth.start();
      await tester.pumpWidget(KivaApp(auth: auth));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un correo válido.'), findsOneWidget);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets(
    'Login real del repositorio muestra resumen personal y cierra la ruta privada',
    (tester) async {
      final api = ApiClient(
        store: fixtures.MemoryStore(),
        dio: Dio()
          ..httpClientAdapter = fixtures.Adapter((request) {
            if (request.path == '/auth/login') {
              return fixtures.reply(
                200,
                fixtures.payload,
                cookie: fixtures.sessionCookie,
              );
            }
            return fixtures.reply(200, {
              'groups_count': 3,
              'trips_count': 1,
              'total_expenses': '15000.00',
            });
          }),
      );
      final auth = AuthController(AuthRepository(api));
      await auth.start();
      await tester.pumpWidget(KivaApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () =>
            auth.submit(email: 'ana@example.com', password: 'example-password'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Mi espacio de trabajo'), findsNothing);
      await tester.runAsync(auth.signOut);
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Hola, Ana Pérez'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets('Registro se adapta a pantalla estrecha y texto grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthController(
      AuthRepository(ApiClient(store: fixtures.MemoryStore())),
    );
    await auth.start();
    await tester.pumpWidget(KivaApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Crear una cuenta'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    final firstName = find.byWidgetPredicate(
      (w) => w is InputDecorator && w.decoration.labelText == 'Primer nombre',
    );
    await tester.scrollUntilVisible(
      firstName,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(firstName, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
