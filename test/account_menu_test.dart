import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/widgets/account_menu.dart';
import 'session_test.dart' as fixtures;

void main() {
  for (final role in GlobalRole.values) {
    for (final brightness in Brightness.values) {
      testWidgets('Menú de cuenta: $role, $brightness, pantalla estrecha', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final account = Account(
          id: 1,
          name: 'Ana Pérez',
          username: 'ana',
          email: 'ana@example.com',
          role: role,
        );
        final auth =
            AuthBloc(AuthRepository(ApiClient(store: fixtures.MemoryStore())))
              ..emit(
                AuthState(
                  phase: AuthPhase.signedIn,
                  account: account,
                  busy: false,
                  error: null,
                ),
              );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                appBar: AppBar(actions: [AccountMenu(auth: auth)]),
              ),
            ),
            for (final path in ['/perfil', '/configuracion', '/workspace'])
              GoRoute(
                path: path,
                builder: (_, _) => Scaffold(body: Text('Destino $path')),
              ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            theme: ThemeData(brightness: brightness),
            routerConfig: router,
          ),
        );
        Future<void> open() async {
          await tester.tap(find.byTooltip('Menú de cuenta'));
          await tester.pumpAndSettle();
        }

        await open();
        expect(find.text(account.name), findsOneWidget);
        expect(find.text(account.email), findsOneWidget);
        expect(find.text(account.roleLabel), findsOneWidget);
        expect(
          find.text('Espacio de trabajo'),
          account.isStaff ? findsOneWidget : findsNothing,
        );
        expect(find.text('Cerrar sesión'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final entry in {
          'Mi perfil': '/perfil',
          'Configuración': '/configuracion',
          if (account.isStaff) 'Espacio de trabajo': '/workspace',
        }.entries) {
          await tester.ensureVisible(find.text(entry.key));
          await tester.tap(find.text(entry.key));
          await tester.pumpAndSettle();
          expect(find.text('Destino ${entry.value}'), findsOneWidget);
          router.go('/');
          await tester.pumpAndSettle();
          await open();
        }
        await tester.pumpWidget(const SizedBox());
        router.dispose();
          auth.dispose();
          await tester.pump();
      });
    }
  }
}
