import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'core/preferences.dart';
import 'features/profile/pages/profile_page.dart';
import 'features/help/pages/support_page.dart';
import 'features/help/data/support_repository.dart';
import 'shared/widgets.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/auth/models/account.dart';
import 'features/auth/pages/auth_page.dart';
import 'features/auth/pages/auth_surface.dart';
import 'features/auth/pages/welcome_page.dart';
import 'features/dashboard/pages/dashboard_page.dart';
import 'features/dashboard/repositories/dashboard_repository.dart';

class KivaApp extends StatefulWidget {
  const KivaApp({
    super.key,
    required this.auth,
    this.preferences,
    this.imagePicker,
  });
  final AuthController auth;
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
        AppPreferences(SecurePreferencesStore('kiva_mobile_settings'));
    if (!_preferences.loaded) _preferences.load();
    final auth = widget.auth;
    final repository = DashboardRepository(auth.repository.api);
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
        if (auth.phase != AuthPhase.signedIn) return public ? null : '/welcome';
        if ((public && path != '/ayuda') || path == '/loading') {
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
        GoRoute(
          path: '/reportes',
          builder: (_, _) => SupportReports(
            repository: SupportRepository(auth.repository.api),
          ),
        ),
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
          builder: (_, _) => DashboardPage(
            auth: auth,
            repository: repository,
            workspace: true,
          ),
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
