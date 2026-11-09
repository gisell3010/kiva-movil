import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:kiva_mobile_final/services/theme.dart';
import 'package:kiva_mobile_final/services/preferences.dart';
import 'package:kiva_mobile_final/pages/help/support_page.dart';
import 'package:kiva_mobile_final/repositories/help/support_repository.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/pages/auth/auth_page.dart';
import 'package:kiva_mobile_final/pages/auth/auth_surface.dart';
import 'package:kiva_mobile_final/pages/auth/welcome_page.dart';
import 'package:kiva_mobile_final/pages/dashboard/dashboard_page.dart';
import 'package:kiva_mobile_final/repositories/dashboard/dashboard_repository.dart';
import 'package:kiva_mobile_final/pages/profile/profile_page.dart';
import 'package:kiva_mobile_final/repositories/workspace/kiva_api.dart';
import 'package:kiva_mobile_final/pages/workspace/workspace_page.dart';
import 'package:kiva_mobile_final/pages/workspace/diagnostic_page.dart';

class KivaApp extends StatefulWidget {
  const KivaApp({
    super.key,
    required this.auth,
    this.preferences,
    this.imagePicker,
  });
  final AuthBloc auth;
  final AppPreferences? preferences;
  final ImagePicker? imagePicker;
  @override
  State<KivaApp> createState() => _KivaAppState();
}

class _KivaAppState extends State<KivaApp> {
  late final GoRouter _router;
  late final AppPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences =
        widget.preferences ??
        AppPreferences(SecurePreferencesStore('kiva_final_settings'));
    if (!_preferences.loaded) _preferences.load();
    final auth = widget.auth;
    final repository = DashboardRepository(auth.repository.api);
    final api = KivaApi(auth.repository.api);
    int? tripQuery(GoRouterState state) =>
        int.tryParse(state.uri.queryParameters['trip'] ?? '');
    int? groupQuery(GoRouterState state) =>
        int.tryParse(state.uri.queryParameters['group_id'] ?? '');
    _router = GoRouter(
      initialLocation: '/loading',
      refreshListenable: auth,
      redirect: (context, state) {
        final path = state.uri.path;
        if (auth.phase == AuthPhase.starting ||
            auth.phase == AuthPhase.unavailable) {
          return path == '/loading' ? null : '/loading';
        }
        final public =
            path == '/welcome' ||
            path == '/login' ||
            path == '/register' ||
            path == '/ayuda';
        final authEntry =
            path == '/welcome' || path == '/login' || path == '/register';
        if (auth.phase != AuthPhase.signedIn) return public ? null : '/welcome';
        if (authEntry || path == '/loading') {
          return auth.account!.isStaff ? '/workspace' : '/dashboard';
        }
        if (path.startsWith('/super-admin') &&
            auth.account!.role != GlobalRole.superAdmin) {
          return '/dashboard';
        }
        if (path.startsWith('/admin') && !auth.account!.isAdmin) {
          return '/dashboard';
        }
        if (path.startsWith('/soporte') && !auth.account!.isStaff) {
          return '/dashboard';
        }
        if (path == '/workspace' && !auth.account!.isStaff) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
        GoRoute(
          path: '/loading',
          builder: (_, _) => AnimatedBuilder(
            animation: auth,
            builder: (context, _) => AuthSurface(
              child: Scaffold(
                body: PageBody(
                  children: [
                    const SizedBox(height: 80),
                    const Center(child: KivaLogo(size: 128)),
                    const SizedBox(height: 32),
                    if (auth.phase == AuthPhase.starting)
                      const Center(child: CircularProgressIndicator())
                    else
                      Notice(
                        auth.error ?? 'No pudimos recuperar tu sesión.',
                        onRetry: auth.start,
                      ),
                    if (auth.phase == AuthPhase.unavailable)
                      TextButton(
                        onPressed: auth.signOut,
                        child: const Text('Usar otra cuenta'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => AuthPage(key: const ValueKey('login'), auth: auth),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => AuthPage(
            key: const ValueKey('register'),
            auth: auth,
            register: true,
          ),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => DashboardPage(auth: auth, repository: repository),
        ),
        GoRoute(
          path: '/workspace',
          builder: (_, _) => WorkspacePage(
            auth: auth,
            api: api,
            section: switch (auth.account?.role) {
              GlobalRole.support => 'support',
              GlobalRole.admin => 'admin',
              GlobalRole.superAdmin => 'super-admin',
              _ => 'support',
            },
          ),
        ),
        GoRoute(
          path: '/grupos',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'groups'),
        ),
        GoRoute(
          path: '/viajes',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'trips'),
        ),
        GoRoute(
          path: '/viajes/nuevo',
          builder: (_, _) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'trips',
            openCreate: true,
          ),
        ),
        GoRoute(
          path: '/participantes',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'participants'),
        ),
        GoRoute(
          path: '/destinos',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'destinations',
            initialTripId: tripQuery(state),
          ),
        ),
        GoRoute(
          path: '/itinerario',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'activities',
            initialTripId: tripQuery(state),
          ),
        ),
        GoRoute(
          path: '/gastos',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'expenses',
            initialTripId: tripQuery(state),
          ),
        ),
        GoRoute(
          path: '/votaciones',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'polls',
            initialTripId: tripQuery(state),
          ),
        ),
        GoRoute(
          path: '/reservas',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'reservations',
            initialTripId: tripQuery(state),
          ),
        ),
        GoRoute(
          path: '/calendario',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'calendar',
            initialTripId: tripQuery(state),
          ),
        ),
        GoRoute(
          path: '/notificaciones',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'notifications'),
        ),
        GoRoute(
          path: '/reportes',
          builder: (_, _) => SupportReports(
            repository: SupportRepository(auth.repository.api),
          ),
        ),
        GoRoute(
          path: '/soporte',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'support'),
        ),
        GoRoute(
          path: '/soporte/reportes',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'support-reports'),
        ),
        GoRoute(
          path: '/soporte/usuarios',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'support-users'),
        ),
        GoRoute(
          path: '/soporte/diagnostico',
          builder: (_, state) => DiagnosticPage(
            auth: auth,
            api: api,
            userId: int.tryParse(state.uri.queryParameters['user'] ?? ''),
          ),
        ),
        GoRoute(
          path: '/admin',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'admin'),
        ),
        GoRoute(
          path: '/admin/usuarios',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'admin-users'),
        ),
        GoRoute(
          path: '/admin/grupos',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'admin-groups'),
        ),
        GoRoute(
          path: '/admin/viajes',
          builder: (_, state) => WorkspacePage(
            auth: auth,
            api: api,
            section: 'admin-trips',
            initialGroupId: groupQuery(state),
          ),
        ),
        GoRoute(
          path: '/admin/vision-general',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'admin'),
        ),
        GoRoute(
          path: '/super-admin',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'super-admin'),
        ),
        GoRoute(
          path: '/super-admin/configuracion',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'super-config'),
        ),
        GoRoute(
          path: '/super-admin/auditoria',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'super-audit'),
        ),
        GoRoute(
          path: '/super-admin/salud',
          builder: (_, _) =>
              WorkspacePage(auth: auth, api: api, section: 'super-health'),
        ),
        GoRoute(
          path: '/perfil',
          builder: (_, _) =>
              ProfilePage(auth: auth, imagePicker: widget.imagePicker),
        ),
        GoRoute(
          path: '/configuracion',
          builder: (_, _) => ProfilePage(
            auth: auth,
            settingsOnly: true,
            imagePicker: widget.imagePicker,
          ),
        ),
        GoRoute(
          path: '/ayuda',
          builder: (_, _) => SupportPage(auth: auth),
        ),
        GoRoute(path: '/account', redirect: (_, _) => '/perfil'),
      ],
      errorBuilder: (context, _) => Scaffold(
        body: PageBody(
          children: [
            const Notice('No encontramos esta página.'),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    if (widget.preferences == null) _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _preferences,
    builder: (context, _) => PreferencesScope(
      preferences: _preferences,
      child: MaterialApp.router(
        title: 'KIVA',
        debugShowCheckedModeBanner: false,
        theme: kivaTheme(
          Brightness.light,
          highContrast: _preferences.highContrast,
        ),
        darkTheme: kivaTheme(
          Brightness.dark,
          highContrast: _preferences.highContrast,
        ),
        highContrastTheme: kivaTheme(Brightness.light, highContrast: true),
        highContrastDarkTheme: kivaTheme(Brightness.dark, highContrast: true),
        themeMode: _preferences.theme,
        themeAnimationDuration: _preferences.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              disableAnimations:
                  media.disableAnimations || _preferences.reduceMotion,
              highContrast: media.highContrast || _preferences.highContrast,
            ),
            child: child!,
          );
        },
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      ),
    ),
  );
}
