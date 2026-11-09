import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/widgets/user_avatar.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';

enum _AccountAction { profile, settings, workspace, signOut }

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key, required this.auth});

  final AuthBloc auth;

  Future<void> _select(BuildContext context, _AccountAction action) async {
    if (auth.account == null || auth.busy) return;
    switch (action) {
      case _AccountAction.profile:
        context.push('/perfil');
      case _AccountAction.settings:
        context.push('/configuracion');
      case _AccountAction.workspace:
        if (auth.account!.isStaff) context.go('/workspace');
      case _AccountAction.signOut:
        if (await confirmAction(
          context,
          'Cerrar sesión',
          '¿Quieres salir de KIVA en este dispositivo?',
        )) {
          await auth.signOut();
        }
    }
  }

  PopupMenuItem<_AccountAction> _item(
    _AccountAction action,
    String label,
    IconData icon,
  ) => PopupMenuItem(
    value: action,
    child: Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    bloc: auth,
    builder: (context, state) {
      final account = state.account;
      final theme = Theme.of(context);
      return PopupMenuButton<_AccountAction>(
        tooltip: 'Menú de cuenta',
        enabled: account != null && !state.busy,
        position: PopupMenuPosition.under,
        constraints: BoxConstraints(
          maxWidth: math.min(320, MediaQuery.sizeOf(context).width - 32),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (action) => _select(context, action),
        itemBuilder: (context) => [
          if (account != null)
            PopupMenuItem<_AccountAction>(
              enabled: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(account.email, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      account.roleLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const PopupMenuDivider(),
          _item(_AccountAction.profile, 'Mi perfil', Icons.person_outline),
          _item(
            _AccountAction.settings,
            'Configuración',
            Icons.settings_outlined,
          ),
          if (account?.isStaff == true)
            _item(
              _AccountAction.workspace,
              'Espacio de trabajo',
              Icons.work_outline,
            ),
          const PopupMenuDivider(),
          _item(_AccountAction.signOut, 'Cerrar sesión', Icons.logout),
        ],
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: UserAvatar(auth: auth, radius: 20),
        ),
      );
    },
  );
}
