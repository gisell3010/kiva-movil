import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kiva_mobile_final/services/api_client.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kiva_mobile_final/bloc/dashboard/dashboard_bloc.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';
import 'package:kiva_mobile_final/widgets/account_menu.dart';
import 'package:kiva_mobile_final/widgets/main_navigation.dart';
import 'package:kiva_mobile_final/models/money.dart';
import 'package:kiva_mobile_final/models/account.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/widgets/workspace_drawer.dart';
import 'package:kiva_mobile_final/repositories/dashboard/dashboard_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.auth,
    required this.repository,
    this.workspace = false,
  });
  final AuthBloc auth;
  final DashboardRepository repository;
  final bool workspace;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardBloc _bloc;
  Json? get _data => _bloc.state.data;
  String? get _error => _bloc.state.error;
  bool get _loading => _bloc.state.loading;
  @override
  void initState() {
    super.initState();
    _bloc = DashboardBloc(widget.repository);
    load();
  }

  Future<void> load() async {
    final user = widget.auth.account;
    if (user == null) return;
    await _bloc.refresh(
      DashboardRequested(account: user, workspace: widget.workspace),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  static const labels = {
    'groups_count': 'Grupos',
    'trips_count': 'Viajes',
    'participants_count': 'Participantes',
    'upcoming_activities_count': 'Próximas actividades',
    'unread_notifications_count': 'Sin leer',
    'open_polls_count': 'Votaciones abiertas',
    'total_expenses': 'Gastos compartidos · COP',
    'users_count': 'Cuentas',
    'active_users_count': 'Cuentas activas',
    'suspended_users_count': 'Cuentas suspendidas',
    'active_trips_count': 'Viajes activos',
    'expenses_count': 'Gastos registrados',
    'reservations_count': 'Reservas',
    'polls_count': 'Votaciones',
    'open_reports_count': 'Reportes abiertos',
    'in_review_reports_count': 'Reportes en revisión',
    'escalated_reports_count': 'Reportes escalados',
    'resolved_reports_count': 'Reportes resueltos',
    'unassigned_reports_count': 'Reportes sin asignar',
  };
  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _bloc,
    child: BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) => _buildDashboard(context),
    ),
  );

  Widget _buildDashboard(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      final user = widget.auth.account;
      final colors = Theme.of(context).colorScheme;
      return Scaffold(
        drawer: WorkspaceDrawer(account: user),
        appBar: AppBar(
          centerTitle: true,
          title: const Brand(),
          actions: [
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: () => context.push('/notificaciones'),
              icon: const Icon(Icons.notifications_none),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: AccountMenu(auth: widget.auth),
            ),
          ],
        ),
        body: PageBody(
          onRefresh: load,
          children: [
            Text(
              'Hola, ${user?.name ?? ''}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.workspace
                  ? 'Tu resumen de ${user?.roleLabel.toLowerCase() ?? ''}'
                  : 'Tus viajes de un vistazo.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (_loading && _data == null)
              const LinearProgressIndicator(
                semanticsLabel: 'Cargando tu resumen',
              ),
            if (_error != null) Notice(_error!, onRetry: load),
            if (_data != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(16) > 23;
                  final columns = largeText || constraints.maxWidth < 280
                      ? 1
                      : constraints.maxWidth > 700
                      ? 3
                      : 2;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (final entry in labels.entries)
                        if (_data!.containsKey(entry.key))
                          SizedBox(
                            width: entry.key == 'total_expenses'
                                ? constraints.maxWidth
                                : width,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      switch (entry.key) {
                                        'groups_count' => Icons.groups_outlined,
                                        'trips_count' =>
                                          Icons.flight_takeoff_outlined,
                                        'total_expenses' =>
                                          Icons.payments_outlined,
                                        'participants_count' =>
                                          Icons.people_outline,
                                        'unread_notifications_count' =>
                                          Icons.notifications_none,
                                        _ => Icons.insights_outlined,
                                      },
                                      color: colors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      entry.key == 'total_expenses'
                                          ? formatMoney(_data![entry.key])
                                          : _data![entry.key].toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.value,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            if (_data != null && !widget.workspace) _recentActivity(context),
            if (_data != null) _quickAccess(context),
            if (!_loading &&
                _error == null &&
                !widget.workspace &&
                _data?['trips_count'] == 0)
              const Notice('Tus próximos viajes aparecerán aquí.'),
            if (user?.isStaff ?? false) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    context.go(widget.workspace ? '/dashboard' : '/workspace'),
                icon: Icon(
                  widget.workspace
                      ? Icons.explore_outlined
                      : Icons.work_outline,
                ),
                label: Text(
                  widget.workspace ? 'Mis viajes' : 'Mi espacio de trabajo',
                ),
              ),
            ],
          ],
        ),
        bottomNavigationBar: const MainNavigation(),
      );
    },
  );

  Widget _quickAccess(BuildContext context) {
    final links = <_DashboardLink>[];
    final data = _data!;
    final account = widget.auth.account;
    void add(String label, IconData icon, String route) {
      links.add(_DashboardLink(label: label, icon: icon, route: route));
    }

    if (widget.workspace) {
      switch (account?.role) {
        case GlobalRole.support:
          if (_positive(data['open_reports_count']) ||
              _positive(data['unassigned_reports_count'])) {
            add('Reportes', Icons.support_agent_outlined, '/soporte/reportes');
          }
          add('Usuarios', Icons.people_outline, '/soporte/usuarios');
        case GlobalRole.admin:
          add('Cuentas', Icons.manage_accounts_outlined, '/admin/usuarios');
          add('Grupos', Icons.groups_outlined, '/admin/grupos');
          add('Viajes', Icons.flight_takeoff_outlined, '/admin/viajes');
        case GlobalRole.superAdmin:
          add('Cuentas', Icons.manage_accounts_outlined, '/admin/usuarios');
          add('Auditoría', Icons.history_outlined, '/super-admin/auditoria');
          add(
            'Configuración',
            Icons.settings_outlined,
            '/super-admin/configuracion',
          );
        case GlobalRole.user:
        case null:
          break;
      }
    } else {
      add('Mis viajes', Icons.flight_takeoff_outlined, '/viajes');
      add('Mis grupos', Icons.groups_outlined, '/grupos');
      add('Gastos', Icons.payments_outlined, '/gastos');
      add('Calendario', Icons.calendar_month_outlined, '/calendario');
      if (_positive(data['open_polls_count'])) {
        add('Votaciones', Icons.how_to_vote_outlined, '/votaciones');
      }
      if (_positive(data['unread_notifications_count'])) {
        add('Notificaciones', Icons.notifications_none, '/notificaciones');
      }
    }

    if (links.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accesos rápidos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in links)
                  OutlinedButton.icon(
                    onPressed: () => context.push(link.route),
                    icon: Icon(link.icon, size: 18, color: colors.primary),
                    label: Text(link.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _positive(Object? value) {
    if (value is num) return value > 0;
    return double.tryParse(value?.toString() ?? '') != null &&
        double.parse(value.toString()) > 0;
  }

  Widget _recentActivity(BuildContext context) {
    final entries = <(String, String, String)>[
      (
        'unread_notifications_count',
        'Notificaciones sin leer',
        '/notificaciones',
      ),
      ('open_polls_count', 'Votaciones abiertas', '/votaciones'),
      ('upcoming_activities_count', 'Próximas actividades', '/itinerario'),
    ];
    final active = entries
        .where((entry) => _positive(_data![entry.$1]))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actividad reciente',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No hay actividad reciente.'),
              ),
            for (final entry in active)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.$2),
                subtitle: Text('${_data![entry.$1]}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(entry.$3),
              ),
            TextButton(
              onPressed: () => context.push('/notificaciones'),
              child: const Text('Ver todas las notificaciones'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLink {
  const _DashboardLink({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
