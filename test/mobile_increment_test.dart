import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiva_mobile_final/pages/app.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/errors.dart';
import 'package:kiva_mobile_final/services/preferences.dart';
import 'package:kiva_mobile_final/services/theme.dart';
import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/repositories/auth/auth_repository.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_controller.dart';
import 'package:kiva_mobile_final/repositories/profile/profile_repository.dart';
import 'package:kiva_mobile_final/pages/profile/profile_page.dart';
import 'package:kiva_mobile_final/repositories/help/support_repository.dart';
import 'package:kiva_mobile_final/pages/help/support_page.dart';
import 'package:kiva_mobile_final/widgets/user_avatar.dart';
import 'session_test.dart' as fixtures;

class MemoryPreferences implements PreferencesStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('unavailable');
    this.value = value;
  }
}

Future<Uint8List> photoBytes() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.purple);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

ApiClient clientFor(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    ApiClient(
      store: fixtures.MemoryStore(),
      dio: Dio()..httpClientAdapter = fixtures.Adapter(handler),
    );
AuthController accountFor(ApiClient client) =>
    AuthController(AuthRepository(client))..emit(
      AuthState(
        phase: AuthPhase.signedIn,
        busy: false,
        error: null,
        account: Account.fromJson(
          Map<String, dynamic>.from(fixtures.payload['user'] as Map),
        ),
      ),
    );
const report = {
  'id': 7,
  'subject': 'No puedo entrar',
  'description': 'Necesito ayuda para entrar.',
  'status': 'OPEN',
  'category': 'ACCESS',
};

class StubPicker extends ImagePicker {
  StubPicker(this.bytes, {this.recover = false});
  final Uint8List bytes;
  final bool recover;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    expect(requestFullMetadata, isFalse);
    return XFile.fromData(bytes, name: 'photo.png', mimeType: 'image/png');
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => recover
      ? LostDataResponse(files: [XFile.fromData(bytes, name: 'photo.png')])
      : LostDataResponse.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (
      status: 'IN_REVIEW',
      staff: true,
      admin: false,
      assigned: 1,
      allowed: true,
    ),
    (
      status: 'ESCALATED',
      staff: true,
      admin: false,
      assigned: 1,
      allowed: false,
    ),
    (status: 'ESCALATED', staff: true, admin: true, assigned: 1, allowed: true),
    (
      status: 'IN_REVIEW',
      staff: true,
      admin: true,
      assigned: 2,
      allowed: false,
    ),
    (status: 'RESOLVED', staff: true, admin: true, assigned: 1, allowed: false),
    (
      status: 'RESOLVED',
      staff: false,
      admin: false,
      assigned: 2,
      allowed: true,
    ),
  ]) {
    testWidgets('Permisos de respuesta: $scenario', (tester) async {
      late SupportRepository repo;
      await tester.runAsync(() async {
        repo = SupportRepository(
          clientFor(
            (r) => fixtures.reply(
              200,
              r.path.endsWith('/messages')
                  ? {'items': [], 'total': 0}
                  : {
                      ...report,
                      'status': scenario.status,
                      'assigned_to_user_id': scenario.assigned,
                    },
            ),
          ),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SupportConversation(
            repository: repo,
            reportId: 7,
            staff: scenario.staff,
            staffId: 1,
            admin: scenario.admin,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Enviar mensaje'),
        scenario.allowed ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'Las rutas de personal no conceden acceso a USER y la barra refleja el alcance',
    (tester) async {
      final paths = <String>[];
      late AuthController auth;
      await tester.runAsync(() async {
        auth = accountFor(
          clientFor((r) {
            paths.add(r.path);
            return fixtures.reply(200, {
              'groups_count': 2,
              'trips_count': 1,
              'total_expenses': '0',
            });
          }),
        );
      });
      await tester.pumpWidget(
        KivaApp(imagePicker: StubPicker(Uint8List(0)), auth: auth),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      for (final path in ['/workspace', '/admin', '/super-admin', '/soporte']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      }
      expect(
        paths.any(
          (path) =>
              path.startsWith('/admin') ||
              path.startsWith('/support') ||
              path.startsWith('/super-admin'),
        ),
        isFalse,
      );
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets(
    'Una selección recuperada tras reinicio vuelve a pedir confirmación',
    (tester) async {
      late AuthController auth;
      late Uint8List bytes;
      var uploads = 0;
      await tester.runAsync(() async {
        bytes = await photoBytes();
        auth = accountFor(
          clientFor((r) {
            uploads++;
            return fixtures.reply(200, {});
          }),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            auth: auth,
            imagePicker: StubPicker(bytes, recover: true),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Tu foto de perfil'), findsOneWidget);
      expect(uploads, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(uploads, 0);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  test(
    'Preferencias persisten tema, contraste y movimiento; un fallo revierte el cambio',
    () async {
      final store = MemoryPreferences();
      final prefs = AppPreferences(store);
      await prefs.load();
      await prefs.update(
        theme: ThemeMode.dark,
        highContrast: true,
        reduceMotion: true,
      );
      final restored = AppPreferences(store);
      await restored.load();
      expect(restored.theme, ThemeMode.dark);
      expect(restored.highContrast, isTrue);
      expect(restored.reduceMotion, isTrue);
      store.fail = true;
      await expectLater(
        restored.update(theme: ThemeMode.light),
        throwsStateError,
      );
      expect(restored.theme, ThemeMode.dark);
      expect(restored.busy, isFalse);
      prefs.dispose();
      restored.dispose();
    },
  );
  test('Preferencias dañadas conservan el tema del sistema', () async {
    final prefs = AppPreferences(MemoryPreferences()..value = '{broken');
    await prefs.load();
    expect(prefs.theme, ThemeMode.system);
    expect(prefs.loaded, isTrue);
    prefs.dispose();
  });
  test('Fotos validan contenido, formato y límite antes de subir', () async {
    expect(
      await ProfileRepository.validateImage(await photoBytes()),
      'image/png',
    );
    for (final invalid in [
      Uint8List(0),
      Uint8List(ProfileRepository.maxImageBytes + 1),
      Uint8List.fromList('GIF89a'.codeUnits),
      Uint8List.fromList([255, 216, 255, 0]),
    ]) {
      await expectLater(
        ProfileRepository.validateImage(invalid),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test(
    'Foto multipart usa FastAPI autenticado y se elimina sin exponer Cloudinary',
    () async {
      final bytes = await photoBytes();
      final requests = <RequestOptions>[];
      final user = {
        ...fixtures.payload['user'] as Map<String, dynamic>,
        'profile_image': 'cloudinary:kiva/profiles/test',
      };
      final client = clientFor((r) {
        requests.add(r);
        if (r.path == '/auth/login') {
          return fixtures.reply(
            200,
            fixtures.payload,
            cookie: fixtures.sessionCookie,
          );
        }
        if (r.method == 'DELETE') return fixtures.reply(204, {});
        return fixtures.reply(200, user);
      });
      await client.authenticate('login', {});
      final auth = accountFor(client);
      final repository = ProfileRepository(client);
      await auth.acceptAccount(await repository.upload(bytes));
      expect(auth.account!.profileImage, user['profile_image']);
      final upload = requests.firstWhere((r) => r.method == 'PUT');
      expect(upload.path, '/users/me/profile-image');
      expect(upload.headers['Authorization'], 'Bearer access-one');
      final form = upload.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.contentType.toString(), 'image/png');
      await repository.deleteImage();
      await auth.removeProfileImage();
      expect(auth.account!.profileImage, isNull);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.path, '/users/me/profile-image');
      auth.dispose();
    },
  );
  test(
    'Cambio de correo respeta el contrato email; fallo no destruye la sesión',
    () async {
      late RequestOptions sent;
      final client = clientFor((r) {
        if (r.path == '/auth/login') {
          return fixtures.reply(
            200,
            fixtures.payload,
            cookie: fixtures.sessionCookie,
          );
        }
        sent = r;
        return fixtures.reply(422, {
          'error': {'code': 'INVALID_PASSWORD'},
        });
      });
      await client.authenticate('login', {});
      final auth = accountFor(client);
      await expectLater(
        ProfileRepository(client).changeEmail(' ANA@EXAMPLE.COM ', 'bad'),
        throwsA(isA<DioException>()),
      );
      expect(sent.data, {
        'email': 'ana@example.com',
        'current_password': 'bad',
      });
      expect(auth.phase, AuthPhase.signedIn);
      expect(client.hasRefreshSession, isTrue);
      auth.dispose();
    },
  );
  test(
    'Una actualización tardía no restaura la identidad tras salir',
    () async {
      final auth = accountFor(clientFor((_) => fixtures.reply(200, {})));
      auth.emit(auth.state.copyWith(phase: AuthPhase.guest, account: null));
      await auth.acceptAccount(
        Map<String, dynamic>.from(fixtures.payload['user'] as Map),
      );
      expect(auth.account, isNull);
      auth.dispose();
    },
  );
  test(
    'Reportes privados recorren páginas y envían mensajes sin notas internas',
    () async {
      final requests = <RequestOptions>[];
      final repo = SupportRepository(
        clientFor((r) {
          requests.add(r);
          if (r.method == 'GET') {
            return fixtures.reply(200, {
              'items': [
                {...report, 'id': r.queryParameters['page']},
              ],
              'total': 2,
            });
          }
          return fixtures.reply(201, report);
        }),
      );
      expect((await repo.reports()).length, 2);
      await repo.create({
        'category': 'TRIP',
        'subject': 'Viaje',
        'description': 'Ayuda',
        'trip_id': 5,
      });
      expect(requests.last.path, '/support-reports');
      expect((requests.last.data as Map)['trip_id'], 5);
      await repo.reply(7, ' Hola ', internal: true);
      expect(requests.last.data, {'body': 'Hola', 'is_internal': false});
    },
  );
  test(
    'Ayuda pública usa código en cuerpo, sin bearer ni cookie de sesión',
    () async {
      final requests = <RequestOptions>[];
      final token = 'a' * 32;
      final client = clientFor((r) {
        requests.add(r);
        if (r.path == '/auth/login') {
          return fixtures.reply(
            200,
            fixtures.payload,
            cookie: fixtures.sessionCookie,
          );
        }
        if (r.path.endsWith('/messages')) {
          return fixtures.reply(200, {'items': [], 'total': 0});
        }
        return fixtures.reply(200, {...report, 'tracking_token': token});
      });
      await client.authenticate('login', {});
      final repo = SupportRepository(client);
      await repo.create({
        'contact_email': 'ana@example.com',
        'category': 'ACCESS',
        'subject': 'Acceso',
        'description': 'Ayuda',
      }, public: true);
      await repo.detail(7, token: token);
      await repo.messages(7, token: token);
      await repo.reply(7, 'Ayuda', token: token);
      for (final r in requests.skip(1)) {
        expect(r.headers['Authorization'], isNull);
        expect(r.headers['Cookie'], isNull);
        expect(r.queryParameters.containsKey('tracking_token'), isFalse);
      }
      expect(requests.last.data, {
        'report_id': 7,
        'tracking_token': token,
        'body': 'Ayuda',
      });
    },
  );

  testWidgets(
    'Foto requiere vista previa y confirmación; cancelar no envía datos',
    (tester) async {
      late AuthController auth;
      late Uint8List bytes;
      var uploads = 0;
      await tester.runAsync(() async {
        bytes = await photoBytes();
        auth = accountFor(
          clientFor((r) {
            if (r.method == 'PUT') uploads++;
            return fixtures.reply(200, fixtures.payload['user']!);
          }),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: kivaTheme(Brightness.dark),
          home: ProfilePage(auth: auth, imagePicker: StubPicker(bytes)),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Añadir foto'),
      );
      late Future<void> picking;
      await tester.runAsync(() async {
        picking = (button.onPressed as dynamic)() as Future<void>;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Tu foto de perfil'), findsOneWidget);
      expect(uploads, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.runAsync(() => picking);
      await tester.pumpAndSettle();
      expect(uploads, 0);
      expect(auth.account!.profileImage, isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets(
    'Foto confirmada actualiza avatar y quitar foto exige confirmación',
    (tester) async {
      late AuthController auth;
      late Uint8List bytes;
      var uploads = 0;
      var deletes = 0;
      await tester.runAsync(() async {
        bytes = await photoBytes();
        auth = accountFor(
          clientFor((r) {
            if (r.method == 'PUT') {
              uploads++;
              return fixtures.reply(200, {
                ...fixtures.payload['user'] as Map,
                'profile_image': 'cloudinary:kiva/profiles/new',
              });
            }
            if (r.method == 'DELETE') {
              deletes++;
              return fixtures.reply(204, {});
            }
            return ResponseBody.fromBytes(
              bytes,
              200,
              headers: {
                'content-type': ['image/png'],
              },
            );
          }),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: kivaTheme(Brightness.dark),
          home: ProfilePage(auth: auth, imagePicker: StubPicker(bytes)),
        ),
      );
      await tester.pumpAndSettle();
      late Future<void> picking;
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Añadir foto'),
      );
      await tester.runAsync(() async {
        picking = (button.onPressed as dynamic)() as Future<void>;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Usar foto'));
      await tester.pump();
      await tester.runAsync(() => picking);
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(auth.account!.profileImage, isNotNull);
      expect(find.byType(UserAvatar), findsOneWidget);
      late Future<void> deleting;
      final remove = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Quitar foto'),
      );
      await tester.runAsync(() async {
        deleting = (remove.onPressed as dynamic)() as Future<void>;
      });
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.runAsync(() => deleting);
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(auth.account!.profileImage, isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets('Reporte público vacío valida sin enviar solicitudes', (
    tester,
  ) async {
    var requests = 0;
    final repo = SupportRepository(
      clientFor((_) {
        requests++;
        return fixtures.reply(201, report);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: kivaTheme(Brightness.dark),
        home: SupportForm(repository: repo, public: true),
      ),
    );
    await tester.ensureVisible(find.text('Enviar reporte'));
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Reporte cerrado muestra conversación sin ofrecer respuesta', (
    tester,
  ) async {
    late SupportRepository repo;
    await tester.runAsync(() async {
      repo = SupportRepository(
        clientFor(
          (r) => fixtures.reply(
            200,
            r.path.endsWith('/messages')
                ? {
                    'items': [
                      {
                        'author_label': 'Soporte',
                        'body': 'Respuesta',
                        'is_internal': false,
                      },
                    ],
                    'total': 1,
                  }
                : {...report, 'status': 'CLOSED'},
          ),
        ),
      );
    });
    await tester.pumpWidget(
      MaterialApp(home: SupportConversation(repository: repo, reportId: 7)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Respuesta'), findsOneWidget);
    expect(find.text('Enviar mensaje'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Dashboard y perfil se adaptan; tema cambia al instante y se conserva',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      late AuthController auth;
      await tester.runAsync(() async {
        auth = accountFor(
          clientFor(
            (r) => fixtures.reply(200, {
              'groups_count': 2,
              'trips_count': 1,
              'total_expenses': '12000',
            }),
          ),
        );
      });
      final store = MemoryPreferences();
      final prefs = AppPreferences(store);
      await prefs.load();
      await prefs.update(theme: ThemeMode.dark);
      await tester.pumpWidget(
        KivaApp(
          imagePicker: StubPicker(Uint8List(0)),
          auth: auth,
          preferences: prefs,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Mi cuenta'), findsNothing);
      expect(find.byTooltip('Actualizar'), findsNothing);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ayuda y soporte'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ayuda y soporte'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Configuración'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Configuración'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      await prefs.update(
        theme: ThemeMode.light,
        reduceMotion: true,
        highContrast: true,
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Tema'))).brightness,
        Brightness.light,
      );
      expect(
        MediaQuery.of(tester.element(find.text('Tema'))).disableAnimations,
        isTrue,
      );
      final restored = AppPreferences(store);
      await restored.load();
      expect(restored.theme, ThemeMode.light);
      expect(restored.highContrast, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      prefs.dispose();
      restored.dispose();
    },
  );

  testWidgets(
    'Capturas de dashboard, perfil, configuración y ayuda en ambos temas',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const font = String.fromEnvironment('UI_FONT');
      if (font.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader('Roboto')
            ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      late AuthController auth;
      await tester.runAsync(() async {
        auth = accountFor(
          clientFor(
            (r) => fixtures.reply(200, {
              'groups_count': 3,
              'trips_count': 2,
              'participants_count': 8,
              'open_polls_count': 1,
              'total_expenses': '125000',
            }),
          ),
        );
      });
      final prefs = AppPreferences(MemoryPreferences());
      await prefs.load();
      await prefs.update(theme: ThemeMode.dark);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: KivaApp(
            imagePicker: StubPicker(Uint8List(0)),
            auth: auth,
            preferences: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('CAPTURE_UI')) return;
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/qa/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/kiva-logo.png'),
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await tester.pumpAndSettle();
      await capture('dashboard-dark');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await capture('profile-dark');
      await tester.ensureVisible(find.text('Configuración'));
      await tester.ensureVisible(find.text('Configuración'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      await capture('settings-dark');
      await prefs.update(theme: ThemeMode.light);
      await tester.pumpAndSettle();
      await capture('settings-light');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      await capture('profile-light');
      await tester.ensureVisible(find.text('Ayuda y soporte'));
      await tester.tap(find.text('Ayuda y soporte'));
      await tester.pumpAndSettle();
      await capture('support-light');
      await tester.tap(find.text('Reportar un problema'));
      await tester.pumpAndSettle();
      await capture('report-light');
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      prefs.dispose();
    },
  );
}
