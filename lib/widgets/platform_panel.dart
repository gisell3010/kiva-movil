import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kiva_mobile_final/models/money.dart';

/// Presentación móvil de los paneles operativos y parámetros autorizados.
class PlatformPanel extends StatelessWidget {
  const PlatformPanel({super.key, required this.section, required this.data});
  final String section;
  final Map<String, dynamic> data;

  static const labels = <String, String>{
    'users_count': 'Usuarios',
    'active_users_count': 'Usuarios activos',
    'suspended_users_count': 'Usuarios suspendidos',
    'groups_count': 'Grupos',
    'trips_count': 'Viajes',
    'active_trips_count': 'Viajes activos',
    'expenses_count': 'Gastos registrados',
    'reservations_count': 'Reservas',
    'polls_count': 'Votaciones',
    'open_polls_count': 'Votaciones abiertas',
    'total_expenses': 'Total de gastos',
    'open_reports_count': 'Por atender',
    'in_review_reports_count': 'En revisión',
    'escalated_reports_count': 'En administración',
    'resolved_reports_count': 'Resueltos',
    'unassigned_reports_count': 'Sin asignar',
    'SUPER_ADMIN': 'Superadministrador',
    'ADMIN': 'Administrador',
    'SUPPORT': 'Soporte',
    'USER': 'Usuario',
    'ACTIVE': 'Activo',
    'SUSPENDED': 'Suspendido',
    'OWNER': 'Responsable',
    'ORGANIZER': 'Organizador',
    'MEMBER': 'Participante',
    'PLANNING': 'Planificando',
    'CONFIRMED': 'Confirmado',
    'COMPLETED': 'Finalizado',
    'CANCELLED': 'Cancelado',
    'OPEN': 'Abierto',
    'CLOSED': 'Cerrado',
    'IN_REVIEW': 'En revisión',
    'ESCALATED': 'En administración',
    'RESOLVED': 'Resuelto',
    'TRIP': 'Viaje',
    'ACTIVITY': 'Actividad',
    'RESERVATION': 'Reserva',
    'POLL': 'Votación',
    'EXPENSE': 'Gasto',
    'ACCESS': 'Acceso',
    'ACCOUNT': 'Cuenta',
    'VOTING': 'Votaciones',
    'TECHNICAL': 'Funcionamiento',
    'OTHER': 'Otro',
    'PENDING': 'Pendiente de confirmación',
    'PROPOSED': 'Propuesta',
    'APPROVED': 'Aprobada',
    'DONE': 'Realizada',
    'TODO': 'Por realizar',
    'IN_PROGRESS': 'En curso',
  };

  static String display(Object? value) =>
      labels[value?.toString()] ?? value?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    Widget card(String title, List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
    Widget row(String label, Object? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            display(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    Widget link(String label, String path) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
    if (section == 'super-config') {
      final environment = switch (data['environment']) {
        'production' => 'Producción',
        'test' => 'Pruebas',
        _ => 'Desarrollo',
      };
      final bytes = num.tryParse('${data['max_image_bytes']}');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          link('Volver al panel', '/super-admin'),
          card('Aplicación', [
            row('Nombre', data['app_name']),
            row('Entorno', environment),
            row('Prefijo de API', data['api_prefix']),
            row('Moneda', data['currency']),
          ]),
          card('Sesiones', [
            row(
              'Duración del acceso',
              '${data['access_token_minutes'] ?? '—'} min',
            ),
            row(
              'Renovación de sesión',
              '${data['refresh_token_days'] ?? '—'} días',
            ),
          ]),
          card('Imágenes', [
            row(
              'Tamaño máximo',
              bytes == null
                  ? '—'
                  : '${(bytes / 1048576).toStringAsFixed(0)} MB',
            ),
            row('Fotos por destino', data['max_destination_photos']),
          ]),
        ],
      );
    }
    if (section == 'super-health') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          link('Volver al panel', '/super-admin'),
          card('Estado del sistema', [
            row(
              'Servicio',
              data['status'] == 'ok' ? 'Funcionando' : 'No disponible',
            ),
            row(
              'Base de datos',
              data['database'] == 'ok' ? 'Disponible' : 'No disponible',
            ),
          ]),
        ],
      );
    }
    final roles = data['users_by_role'] is Map
        ? Map<String, dynamic>.from(data['users_by_role'])
        : <String, dynamic>{};
    final isSuper = section == 'super-admin';
    final isSupport = section == 'support';
    final keys = isSuper
        ? ['users_count', 'groups_count', 'trips_count']
        : isSupport
        ? [
            'open_reports_count',
            'in_review_reports_count',
            'escalated_reports_count',
            'resolved_reports_count',
          ]
        : ['users_count', 'active_users_count', 'suspended_users_count'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        link('Espacio de usuario', '/dashboard'),
        card('Resumen', [
          for (final key in keys) row(labels[key]!, data[key]),
          if (isSuper)
            row(
              'Equipo de trabajo',
              ['SUPER_ADMIN', 'ADMIN', 'SUPPORT'].fold<int>(
                0,
                (sum, role) => sum + (int.tryParse('${roles[role]}') ?? 0),
              ),
            ),
        ]),
        if (isSuper || section == 'admin')
          card('Distribución de roles', [
            for (final role in ['SUPER_ADMIN', 'ADMIN', 'SUPPORT', 'USER']) ...[
              row(labels[role]!, roles[role] ?? 0),
              LinearProgressIndicator(
                value: _fraction(roles[role], data['users_count']),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
            ],
          ]),
        if (section == 'admin') ...[
          card('Grupos y viajes', [
            for (final key in [
              'groups_count',
              'trips_count',
              'active_trips_count',
            ])
              row(labels[key]!, data[key]),
            link('Supervisar grupos', '/admin/grupos'),
            link('Supervisar viajes', '/admin/viajes'),
          ]),
          card('Actividad de la plataforma', [
            for (final key in [
              'expenses_count',
              'reservations_count',
              'polls_count',
            ])
              row(labels[key]!, data[key]),
            row(
              'Total de gastos · COP',
              formatMoney(data['total_expenses'] ?? 0),
            ),
          ]),
        ],
        if (isSupport)
          card('Tu espacio de atención', [
            row('Reportes sin asignar', data['unassigned_reports_count']),
            link('Abrir cola de reportes', '/soporte/reportes'),
            link('Consultar una cuenta', '/soporte/usuarios'),
          ]),
        for (final recent in [
          ('recent_reports', 'Últimas solicitudes', '/soporte/reportes'),
          ('recent_users', 'Usuarios recientes', '/admin/usuarios'),
          ('recent_groups', 'Grupos recientes', '/admin/grupos'),
        ])
          if (data[recent.$1] is List)
            card(recent.$2, [
              if ((data[recent.$1] as List).isEmpty)
                const Text('No hay registros para mostrar.'),
              for (final item in (data[recent.$1] as List).whereType<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item['subject'] ?? item['full_name'] ?? item['name'] ?? 'Registro'}',
                  ),
                  subtitle: Text(
                    display(
                      item['status'] ?? item['role'] ?? item['description'],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(recent.$3),
                ),
              link('Ver todos', recent.$3),
            ]),
        card('Accesos rápidos', [
          if (isSuper) ...[
            link('Configuración del sistema', '/super-admin/configuracion'),
            link('Registro de auditoría', '/super-admin/auditoria'),
            link('Salud del sistema', '/super-admin/salud'),
            link('Panel de administración', '/admin'),
          ],
          if (section == 'admin') ...[
            link('Gestión de usuarios', '/admin/usuarios'),
            link('Reportes de soporte', '/soporte/reportes'),
          ],
          if (isSupport) link('Diagnóstico de viajes', '/soporte/diagnostico'),
        ]),
      ],
    );
  }

  double _fraction(Object? count, Object? total) {
    final maximum = double.tryParse('$total') ?? 0;
    return maximum <= 0
        ? 0
        : ((double.tryParse('$count') ?? 0) / maximum).clamp(0, 1);
  }
}
