import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets.dart';
import '../state/auth_controller.dart';
import 'auth_surface.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth, this.register = false});
  final AuthController auth;
  final bool register;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _visiblePasswords = <String>{};
  final _focusNodes = <String, FocusNode>{};
  bool _submitted = false;
  bool _showRemoteError = false;
  String? _formError;
  TextEditingController field(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);
  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Widget input(
    String key,
    String label, {
    String? Function(String?)? validator,
    bool password = false,
    TextInputType? keyboard,
    Iterable<String>? autofill,
    int maxLength = 150,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      key: ValueKey(key),
      controller: field(key),
      validator: validator,
      focusNode: _focusNodes.putIfAbsent(key, FocusNode.new),
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      enabled: !widget.auth.busy,
      obscureText: password && !_visiblePasswords.contains(key),
      autocorrect:
          !password &&
          keyboard != TextInputType.emailAddress &&
          key != 'username',
      enableSuggestions: !password && key != 'email' && key != 'username',
      textCapitalization: key.contains('name') && key != 'username'
          ? TextCapitalization.words
          : TextCapitalization.none,
      keyboardType:
          keyboard ??
          (password ? TextInputType.visiblePassword : TextInputType.text),
      textInputAction:
          (key == 'confirm' || (key == 'password' && !widget.register))
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (key == 'confirm' || (key == 'password' && !widget.register)) {
          submit();
        }
      },
      autofillHints: autofill,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        helperText: key == 'password' && widget.register
            ? 'Usa entre 10 y 128 caracteres.'
            : null,
        suffixIcon: password
            ? IconButton(
                tooltip: !_visiblePasswords.contains(key)
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                icon: Icon(
                  !_visiblePasswords.contains(key)
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: widget.auth.busy
                    ? null
                    : () => setState(() {
                        if (!_visiblePasswords.remove(key)) {
                          _visiblePasswords.add(key);
                        }
                      }),
              )
            : null,
      ),
    ),
  );
  Future<void> submit() async {
    if (widget.auth.busy) return;
    setState(() {
      _submitted = true;
      _formError = null;
      _showRemoteError = false;
    });
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      final first = invalid.first;
      final key = first.widget.key! as ValueKey<String>;
      _focusNodes[key.value]?.requestFocus();
      await Scrollable.ensureVisible(first.context, alignment: .2);
      return;
    }
    setState(() => _showRemoteError = true);
    Json? registration;
    if (widget.register) {
      final names = [
        'first_name',
        'second_name',
        'first_last_name',
        'second_last_name',
      ];
      final fullName = names
          .map((key) => field(key).text.trim())
          .where((s) => s.isNotEmpty)
          .join(' ');
      if (fullName.length > 120) {
        setState(
          () => _formError =
              'El nombre completo debe tener hasta 120 caracteres.',
        );
        return;
      }
      registration = {
        for (final key in names)
          key: field(key).text.trim().isEmpty ? null : field(key).text.trim(),
        'username': field('username').text.trim().toLowerCase(),
        'email': field('email').text.trim().toLowerCase(),
        'password': field('password').text,
      };
    }
    FocusScope.of(context).unfocus();
    await widget.auth.submit(
      email: field('email').text,
      password: field('password').text,
      registration: registration,
    );
    if (!mounted) return;
    if (widget.auth.phase == AuthPhase.signedIn) {
      TextInput.finishAutofillContext();
      field('password').clear();
      field('confirm').clear();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) => AuthSurface(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.auth.busy ? null : () => context.go('/welcome'),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    onChanged: () {
                      if (_showRemoteError || _formError != null) {
                        setState(() {
                          _showRemoteError = false;
                          _formError = null;
                        });
                      }
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: KivaLogo()),
                          const SizedBox(height: 24),
                          Text(
                            widget.register
                                ? 'Crea tu cuenta'
                                : 'Bienvenido de nuevo',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.register
                                ? 'Organiza tu próximo viaje en grupo.'
                                : 'Tus viajes, en un solo lugar.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 32),
                          if (widget.register) ...[
                            input(
                              'first_name',
                              'Primer nombre',
                              maxLength: 60,
                              validator: Validators.personName,
                              autofill: const [AutofillHints.givenName],
                            ),
                            input(
                              'second_name',
                              'Segundo nombre (opcional)',
                              maxLength: 60,
                              validator: (v) => Validators.personName(v, optional: true),
                            ),
                            input(
                              'first_last_name',
                              'Primer apellido',
                              maxLength: 60,
                              validator: Validators.personName,
                              autofill: const [AutofillHints.familyName],
                            ),
                            input(
                              'second_last_name',
                              'Segundo apellido (opcional)',
                              maxLength: 60,
                              validator: (v) => Validators.personName(v, optional: true),
                            ),
                            input(
                              'username',
                              'Nombre de usuario',
                              maxLength: 50,
                              validator: Validators.username,
                              autofill: const [AutofillHints.newUsername],
                            ),
                          ],
                          input(
                            'email',
                            'Correo electrónico',
                            validator: Validators.email,
                            keyboard: TextInputType.emailAddress,
                            autofill: const [AutofillHints.email],
                          ),
                          input(
                            'password',
                            'Contraseña',
                            password: true,
                            maxLength: 128,
                            validator: (v) => Validators.password(
                              v,
                              registration: widget.register,
                            ),
                            autofill: [
                              widget.register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                          ),
                          if (widget.register) ...[
                            input(
                              'confirm',
                              'Confirma tu contraseña',
                              password: true,
                              maxLength: 128,
                              validator: (v) =>
                                  v == field('password').text &&
                                      (v?.isNotEmpty ?? false)
                                  ? null
                                  : 'Las contraseñas no coinciden.',
                            ),
                          ],
                          if (_formError != null ||
                              (_showRemoteError && widget.auth.error != null))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Notice(_formError ?? widget.auth.error!),
                              ),
                            ),
                          FilledButton(
                            onPressed: widget.auth.busy ? null : submit,
                            child: widget.auth.busy
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      semanticsLabel: widget.register
                                          ? 'Creando cuenta'
                                          : 'Iniciando sesión',
                                    ),
                                  )
                                : Text(
                                    widget.register
                                        ? 'Crear cuenta'
                                        : 'Iniciar sesión',
                                  ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: widget.auth.busy
                                ? null
                                : () => context.pushReplacement(
                                    widget.register ? '/login' : '/register',
                                  ),
                            child: Text(
                              widget.register
                                  ? 'Ya tengo una cuenta'
                                  : 'Crear una cuenta',
                            ),
                          ),
                          TextButton(
                            onPressed: widget.auth.busy
                                ? null
                                : () => context.push('/ayuda'),
                            child: const Text('¿Necesitas ayuda?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
