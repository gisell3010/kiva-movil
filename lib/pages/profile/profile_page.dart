import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:kiva_mobile_final/services/errors.dart';
import 'package:kiva_mobile_final/services/preferences.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';
import 'package:kiva_mobile_final/services/validators.dart';
import 'package:kiva_mobile_final/widgets/user_avatar.dart';
import 'package:kiva_mobile_final/widgets/main_navigation.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/repositories/profile/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.auth,
    this.settingsOnly = false,
    this.imagePicker,
  });
  final AuthBloc auth;
  final bool settingsOnly;
  final ImagePicker? imagePicker;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileRepository _repository = ProfileRepository(
    widget.auth.repository.api,
  );
  late final ImagePicker _picker = widget.imagePicker ?? ImagePicker();
  bool _busy = false;
  bool _sessionsLoading = false;
  String? _error;
  List<Json>? _sessions;
  @override
  void initState() {
    super.initState();
    if (!widget.settingsOnly &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _busy = true;
      _recoverPhoto();
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.files?.isNotEmpty ?? false) {
        setState(() => _busy = true);
        await _reviewPhoto(response.files!.first);
      } else if (response.exception != null) {
        _message('No pudimos recuperar la foto. Selecciónala de nuevo.');
      }
    } on MissingPluginException {
      // Recovery is only provided by the Android picker.
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _run(Future<void> Function() operation, String message) async {
    if (!mounted) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) _message(message);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
        _message(_error!);
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (photo != null && mounted) await _reviewPhoto(photo);
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewPhoto(XFile file) async {
    if (await file.length() > ProfileRepository.maxImageBytes) {
      throw const AppFailure('Elige una foto de hasta 5 MB.');
    }
    final Uint8List bytes = await file.readAsBytes();
    await ProfileRepository.validateImage(bytes);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tu foto de perfil'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                bytes,
                width: 184,
                height: 184,
                fit: BoxFit.cover,
                cacheWidth: 512,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Así se verá tu foto en KIVA.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usar foto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final user = await _repository.upload(bytes);
      await widget.auth.acceptAccount(user);
    }, 'Foto actualizada.');
  }

  Future<void> _deletePhoto() async {
    if (_busy) return;
    if (!await confirmAction(
      context,
      'Quitar foto',
      '¿Quieres quitar tu foto de perfil?',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      await _repository.deleteImage();
      await widget.auth.removeProfileImage();
    }, 'Foto eliminada.');
  }

  Future<void> _loadSessions() async {
    if (_sessionsLoading) return;
    setState(() => _sessionsLoading = true);
    try {
      final data = await _repository.sessions();
      if (mounted) {
        setState(
          () => _sessions = data.where((s) => s['revoked_at'] == null).toList(),
        );
      }
    } catch (error) {
      if (mounted) _message(friendlyError(error));
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  Future<void> _revoke(Json session) async {
    if (_busy) return;
    if (!await confirmAction(
      context,
      'Cerrar sesión',
      'Este dispositivo tendrá que volver a iniciar sesión.',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      final id = session['id'] as int;
      final current = widget.auth.repository.api.sessionId == id;
      await _repository.revoke(id);
      if (current) {
        await widget.auth.repository.api.clearSession();
      } else {
        await _loadSessions();
      }
    }, 'Sesión cerrada.');
  }

  Future<void> _logoutAll() async {
    if (_busy) return;
    if (!await confirmAction(
      context,
      'Cerrar todas las sesiones',
      'Tendrás que iniciar sesión de nuevo en todos tus dispositivos.',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      await _repository.logoutAll();
      await widget.auth.repository.api.clearSession();
    }, 'Sesiones cerradas.');
  }

  String _date(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null
        ? 'Fecha no disponible'
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }

  Future<void> _edit(String kind) async {
    if (_busy) return;
    final name = TextEditingController(text: widget.auth.account?.name);
    final username = TextEditingController(text: widget.auth.account?.username);
    final email = TextEditingController();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    bool sending = false;
    String? error;
    final hidden = <String, bool>{};
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          Widget input(
            TextEditingController controller,
            String label,
            String? Function(String?) validate, {
            bool password = false,
            bool isEmail = false,
            bool last = false,
            int limit = 128,
          }) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: controller,
              enabled: !sending,
              validator: validate,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: password && (hidden[label] ?? true),
              autocorrect: !password && !isEmail && controller == name,
              enableSuggestions: !password,
              maxLength: limit,
              keyboardType: isEmail
                  ? TextInputType.emailAddress
                  : password
                  ? TextInputType.visiblePassword
                  : TextInputType.text,
              textInputAction: last
                  ? TextInputAction.done
                  : TextInputAction.next,
              textCapitalization: controller == name
                  ? TextCapitalization.words
                  : TextCapitalization.none,
              decoration: InputDecoration(
                labelText: label,
                counterText: '',
                suffixIcon: password
                    ? IconButton(
                        tooltip: (hidden[label] ?? true)
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: sending
                            ? null
                            : () => update(
                                () => hidden[label] = !(hidden[label] ?? true),
                              ),
                        icon: Icon(
                          (hidden[label] ?? true)
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      )
                    : null,
              ),
            ),
          );
          return PopScope(
            canPop: !sending,
            child: AlertDialog(
              title: Text(switch (kind) {
                'profile' => 'Editar perfil',
                'email' => 'Cambiar correo',
                _ => 'Cambiar contraseña',
              }),
              scrollable: true,
              content: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (kind == 'profile') ...[
                      input(
                        name,
                        'Nombre completo',
                        (v) => Validators.personName(v, max: 120),
                        limit: 120,
                      ),
                      input(
                        username,
                        'Nombre de usuario',
                        Validators.username,
                        limit: 50,
                        last: true,
                      ),
                    ] else ...[
                      if (kind == 'email')
                        input(
                          email,
                          'Nuevo correo',
                          (v) {
                            final error = Validators.email(v);
                            if (error != null) return error;
                            if (v!.trim().toLowerCase() ==
                                widget.auth.account?.email.toLowerCase()) {
                              return 'Escribe un correo diferente al actual.';
                            }
                            return null;
                          },
                          isEmail: true,
                          limit: 150,
                        ),
                      input(
                        current,
                        'Contraseña actual',
                        Validators.password,
                        password: true,
                        last: kind == 'email',
                      ),
                      if (kind == 'password') ...[
                        input(
                          next,
                          'Nueva contraseña',
                          (v) => v == current.text
                              ? 'Elige una contraseña diferente.'
                              : Validators.password(v, registration: true),
                          password: true,
                        ),
                        input(
                          confirm,
                          'Confirma la contraseña',
                          (v) => v == next.text && (v?.isNotEmpty ?? false)
                              ? null
                              : 'Las contraseñas no coinciden.',
                          password: true,
                          last: true,
                        ),
                        const Text('Usa entre 10 y 128 caracteres.'),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Después tendrás que iniciar sesión de nuevo.',
                      ),
                    ],
                    if (error != null) Notice(error!),
                    if (sending)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Guardando cambios',
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          FocusScope.of(context).unfocus();
                          update(() {
                            sending = true;
                            error = null;
                          });
                          try {
                            if (kind == 'profile') {
                              await widget.auth.acceptAccount(
                                await _repository.update(
                                  name.text,
                                  username.text,
                                ),
                              );
                            } else if (kind == 'email') {
                              await _repository.changeEmail(
                                email.text,
                                current.text,
                              );
                            } else {
                              await _repository.changePassword(
                                current.text,
                                next.text,
                              );
                            }
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (kind != 'profile') {
                              await widget.auth.repository.api.clearSession();
                            } else {
                              _message('Perfil actualizado.');
                            }
                          } catch (failure) {
                            if (context.mounted) {
                              update(() {
                                error = friendlyError(failure);
                                sending = false;
                              });
                            }
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (mounted) {
      await Navigator.of(context).push(route);
      await route.completed;
    }
    for (final controller in [name, username, email, current, next, confirm]) {
      controller.dispose();
    }
  }

  Widget _preferences() {
    final prefs = AppPreferences.of(context);
    Future<void> save({ThemeMode? theme, bool? contrast, bool? motion}) async {
      try {
        await prefs.update(
          theme: theme,
          highContrast: contrast,
          reduceMotion: motion,
        );
      } catch (_) {
        _message('No pudimos guardar la preferencia. Inténtalo de nuevo.');
      }
    }

    final disabled = prefs.busy || !prefs.loaded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<ThemeMode>(
              key: ValueKey(prefs.theme),
              initialValue: prefs.theme,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tema'),
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Sistema'),
                ),
              ],
              onChanged: disabled ? null : (value) => save(theme: value),
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: prefs.highContrast,
                title: const Text('Mayor contraste'),
                onChanged: disabled ? null : (v) => save(contrast: v),
              ),
              SwitchListTile(
                value: prefs.reduceMotion,
                title: const Text('Reducir movimiento'),
                onChanged: disabled ? null : (v) => save(motion: v),
              ),
            ],
          ),
        ),
        if (prefs.busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Guardando preferencias',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      final user = widget.auth.account;
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.settingsOnly ? 'Configuración' : 'Perfil'),
          leading: widget.settingsOnly
              ? IconButton(
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/perfil');
                    }
                  },
                )
              : null,
        ),
        body: PageBody(
          onRefresh: widget.settingsOnly
              ? null
              : () async {
                  await _run(widget.auth.refreshAccount, 'Perfil actualizado.');
                },
          children: [
            if (_busy)
              const LinearProgressIndicator(
                semanticsLabel: 'Guardando cambios',
              ),
            if (_error != null) Notice(_error!),
            if (widget.settingsOnly)
              _preferences()
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      UserAvatar(auth: widget.auth, radius: 48),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? '',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '', textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text(
                        user?.roleLabel ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: _busy ? null : _pickPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: Text(
                              user?.profileImage == null
                                  ? 'Añadir foto'
                                  : 'Cambiar foto',
                            ),
                          ),
                          if (user?.profileImage != null)
                            TextButton.icon(
                              onPressed: _busy ? null : _deletePhoto,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Quitar foto'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Editar perfil'),
                      subtitle: Text('@${user?.username ?? ''}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _edit('profile'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune_outlined),
                      title: const Text('Configuración'),
                      subtitle: const Text('Tema y accesibilidad'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/configuracion'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Ayuda y soporte'),
                      subtitle: const Text('Reportar un problema'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/ayuda'),
                    ),
                  ],
                ),
              ),
              Card(
                child: ExpansionTile(
                  title: const Text('Seguridad'),
                  leading: const Icon(Icons.shield_outlined),
                  children: [
                    ListTile(
                      title: const Text('Cambiar correo'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _edit('email'),
                    ),
                    ListTile(
                      title: const Text('Cambiar contraseña'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _edit('password'),
                    ),
                  ],
                ),
              ),
              Card(
                child: ExpansionTile(
                  title: const Text('Sesiones'),
                  leading: const Icon(Icons.devices_outlined),
                  onExpansionChanged: (open) {
                    if (open) _loadSessions();
                  },
                  children: [
                    if (_sessionsLoading) const LinearProgressIndicator(),
                    if (_sessions == null && !_sessionsLoading)
                      TextButton(
                        onPressed: _loadSessions,
                        child: const Text('Cargar sesiones'),
                      ),
                    for (final session in _sessions ?? <Json>[])
                      ListTile(
                        title: Text(
                          session['id'] == widget.auth.repository.api.sessionId
                              ? 'Este dispositivo'
                              : 'Sesión activa',
                        ),
                        subtitle: Text(
                          'Inicio: ${_date(session['created_at'])}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Cerrar esta sesión',
                          onPressed: _busy ? null : () => _revoke(session),
                          icon: const Icon(Icons.logout),
                        ),
                      ),
                    TextButton(
                      onPressed: _busy ? null : _logoutAll,
                      child: const Text('Cerrar todas las sesiones'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirmAction(
                          context,
                          'Cerrar sesión',
                          '¿Quieres salir de KIVA en este dispositivo?',
                        )) {
                          await widget.auth.signOut();
                        }
                      },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ],
        ),
        bottomNavigationBar: widget.settingsOnly
            ? null
            : const MainNavigation(profile: true),
      );
    },
  );
}
