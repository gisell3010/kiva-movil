import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile_final/widgets/platform_panel.dart';

void main() {
  testWidgets('Superadministración conserva roles y accesos del mockup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlatformPanel(
              section: 'super-admin',
              data: {
                'users_count': 4,
                'groups_count': 2,
                'trips_count': 3,
                'users_by_role': {
                  'SUPER_ADMIN': 1,
                  'ADMIN': 1,
                  'SUPPORT': 1,
                  'USER': 1,
                },
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('Distribución de roles'), findsOneWidget);
    expect(find.text('Equipo de trabajo'), findsOneWidget);
    expect(find.text('Espacio de usuario'), findsOneWidget);
    expect(find.text('Salud del sistema'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
    expect(find.text('Users Count'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Configuración muestra todas las secciones y unidades en español',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlatformPanel(
                section: 'super-config',
                data: {
                  'app_name': 'KIVA',
                  'environment': 'production',
                  'api_prefix': '/api',
                  'currency': 'COP',
                  'access_token_minutes': 15,
                  'refresh_token_days': 7,
                  'max_image_bytes': 5242880,
                  'max_destination_photos': 10,
                },
              ),
            ),
          ),
        ),
      );
      for (final label in [
        'Aplicación',
        'Sesiones',
        'Imágenes',
        'Producción',
        '15 min',
        '7 días',
        '5 MB',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
