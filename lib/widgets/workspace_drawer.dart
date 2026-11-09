import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';

class WorkspaceDrawer extends StatelessWidget {
  const WorkspaceDrawer({super.key, required this.account});

  final Account? account;

  @override
  Widget build(BuildContext context) {
    final isStaff = account?.isStaff ?? false;
    final isAdmin = account?.isAdmin ?? false;
    final isSuper = account?.role == GlobalRole.superAdmin;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(alignment: Alignment.bottomLeft, child: Brand()),
            ),
            _item(context, 'Inicio', Icons.home_outlined, '/dashboard'),
            _item(context, 'Grupos', Icons.groups_outlined, '/grupos'),
            _item(context, 'Viajes', Icons.flight_takeoff_outlined, '/viajes'),
            _item(
              context,
              'Participantes',
              Icons.people_outline,
              '/participantes',
            ),
            _item(context, 'Destinos', Icons.place_outlined, '/destinos'),
            _item(
              context,
              'Itinerario',
              Icons.event_note_outlined,
              '/itinerario',
            ),
            _item(
              context,
              'Gastos y balances',
              Icons.payments_outlined,
              '/gastos',
            ),
            _item(
              context,
              'Votaciones',
              Icons.how_to_vote_outlined,
              '/votaciones',
            ),
            _item(context, 'Reservas', Icons.book_online_outlined, '/reservas'),
            _item(
              context,
              'Calendario',
              Icons.calendar_month_outlined,
              '/calendario',
            ),
            _item(
              context,
              'Notificaciones',
              Icons.notifications_none,
              '/notificaciones',
            ),
            _item(
              context,
              'Mis reportes',
              Icons.support_agent_outlined,
              '/reportes',
            ),
            if (isStaff) ...[
              const Divider(),
              _item(
                context,
                'Panel de soporte',
                Icons.support_outlined,
                '/soporte',
              ),
              _item(
                context,
                'Reportes de soporte',
                Icons.inbox_outlined,
                '/soporte/reportes',
              ),
              _item(
                context,
                'Consulta de usuarios',
                Icons.manage_search_outlined,
                '/soporte/usuarios',
              ),
            ],
            if (isAdmin) ...[
              const Divider(),
              _item(
                context,
                'Administración',
                Icons.admin_panel_settings_outlined,
                '/admin',
              ),
              _item(
                context,
                'Cuentas',
                Icons.badge_outlined,
                '/admin/usuarios',
              ),
              _item(
                context,
                'Supervisión de grupos',
                Icons.groups_2_outlined,
                '/admin/grupos',
              ),
              _item(
                context,
                'Supervisión de viajes',
                Icons.travel_explore_outlined,
                '/admin/viajes',
              ),
            ],
            if (isSuper) ...[
              const Divider(),
              _item(
                context,
                'Superadministración',
                Icons.security_outlined,
                '/super-admin',
              ),
              _item(
                context,
                'Configuración efectiva',
                Icons.tune_outlined,
                '/super-admin/configuracion',
              ),
              _item(
                context,
                'Auditoría',
                Icons.fact_check_outlined,
                '/super-admin/auditoria',
              ),
              _item(
                context,
                'Salud del servicio',
                Icons.health_and_safety_outlined,
                '/super-admin/salud',
              ),
            ],
            const Divider(),
            _item(context, 'Mi perfil', Icons.person_outline, '/perfil'),
            _item(
              context,
              'Configuración',
              Icons.settings_outlined,
              '/configuracion',
            ),
            _item(context, 'Ayuda', Icons.help_outline, '/ayuda'),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String label,
    IconData icon,
    String path,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    onTap: () {
      Navigator.of(context).pop();
      context.go(path);
    },
  );
}
