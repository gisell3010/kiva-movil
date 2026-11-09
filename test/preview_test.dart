import 'dart:io';
import 'package:kiva_mobile_final/services/preferences.dart';
import 'mobile_increment_test.dart' show MemoryPreferences;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile_final/pages/app.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_controller.dart';
import 'session_test.dart' as fixtures;

void main() {
  testWidgets('Bienvenida, acceso y registro conservan la composición móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const fontPath = String.fromEnvironment('UI_FONT');
    if (fontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto');
        loader.addFont(
          File(
            fontPath,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
        final fallback = FontLoader('Ahem');
        fallback.addFont(
          File(
            fontPath,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await fallback.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    final auth = AuthController(
      AuthRepository(ApiClient(store: fixtures.MemoryStore())),
    );
    final startup = auth.start();
    await tester.pump();
    await startup;
    final preferences = AppPreferences(MemoryPreferences());
    await preferences.load();
    await preferences.update(theme: ThemeMode.dark);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: KivaApp(auth: auth, preferences: preferences),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/brand/kiva-logo.png'),
        tester.element(find.byType(Scaffold).first),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/qa/$name.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }

    await capture('welcome');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await capture('login');
    await tester.ensureVisible(find.text('Crear una cuenta'));
    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    await capture('register');
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await capture('register-bottom');
    await preferences.update(theme: ThemeMode.light);
    await tester.pumpAndSettle();
    await capture('register-light');
    await tester.ensureVisible(find.text('Ya tengo una cuenta'));
    await tester.tap(find.text('Ya tengo una cuenta'));
    await tester.pumpAndSettle();
    await capture('login-light');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await capture('welcome-light');
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    preferences.dispose();
  });
}
