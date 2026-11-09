import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kiva_mobile_final/services/errors.dart';
import 'package:kiva_mobile_final/widgets/widgets.dart';
import 'package:kiva_mobile_final/widgets/main_navigation.dart';
import 'package:kiva_mobile_final/pages/help/support_page.dart';
import 'package:kiva_mobile_final/repositories/help/support_repository.dart';
import 'package:kiva_mobile_final/bloc/auth/auth_bloc.dart';
import 'package:kiva_mobile_final/repositories/profile/profile_repository.dart';
import 'package:kiva_mobile_final/bloc/workspace/workspace_bloc.dart';
import 'package:kiva_mobile_final/repositories/workspace/kiva_api.dart';
import 'package:kiva_mobile_final/widgets/workspace_drawer.dart';
import 'package:kiva_mobile_final/widgets/platform_panel.dart';
import 'package:kiva_mobile_final/models/audit_labels.dart';
import 'package:kiva_mobile_final/models/account.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.auth,
    required this.api,
    required this.section,
    this.openCreate = false,
    this.initialTripId,
    this.initialGroupId,
  });

  final AuthBloc auth;
  final KivaApi api;
  final String section;
  final bool openCreate;
  final int? initialTripId;
  final int? initialGroupId;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  bool get _loading => _bloc.state.status == WorkspaceStatus.loading;
  bool get _saving => _bloc.state.status == WorkspaceStatus.saving;
  String? get _error =>
      _bloc.state.error == null ? null : friendlyError(_bloc.state.error!);
  String? _search;
  int? _tripId;
  List<KivaMap> get _items => _bloc.state.items;
  List<KivaMap> get _trips => _bloc.state.trips;
  KivaMap? get _summary => _bloc.state.summary;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool? _notificationReadFilter;
  Map<String, Object?> _filters = <String, Object?>{};
  late final WorkspaceBloc _bloc;

  bool get _tripResource => const {
    'participants',
    'destinations',
    'activities',
    'expenses',
    'polls',
    'reservations',
  }.contains(widget.section);

  @override
  void initState() {
    super.initState();
    _tripId = widget.initialTripId;
    if (widget.initialGroupId != null) {
      _filters['group_id'] = widget.initialGroupId;
    }
    _bloc = WorkspaceBloc(widget.api, section: widget.section);
    _initialize();
  }

  Future<void> _initialize() async {
    await _load();
    if (mounted && widget.openCreate) await _create();
  }

  @override
  void didUpdateWidget(covariant WorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _bloc.section = widget.section;
      _load();
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  int? _id(Object? value) =>
      value is int ? value : int.tryParse(value.toString());

  String _text(Object? value) {
    if (value == null) return '—';
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  Future<void> _load() => _bloc.dispatch(
    WorkspaceLoadRequested(
      search: _search,
      tripId: _tripId,
      calendarMonth: _calendarMonth,
      notificationRead: _notificationReadFilter,
      filters: _filters,
    ),
  );

  String _title() => switch (widget.section) {
    'groups' => 'Grupos',
    'trips' => 'Viajes',
    'participants' => 'Participantes',
    'destinations' => 'Destinos',
    'activities' => 'Itinerario',
    'expenses' => 'Gastos y balances',
    'polls' => 'Votaciones',
    'reservations' => 'Reservas',
    'calendar' => 'Calendario',
    'notifications' => 'Notificaciones',
    'reports' => 'Mis reportes',
    'support' => 'Panel de soporte',
    'support-reports' => 'Reportes de soporte',
    'support-users' => 'Consulta de usuarios',
    'admin' => 'Administración',
    'admin-users' => 'Cuentas',
    'admin-groups' => 'Supervisión de grupos',
    'admin-trips' => 'Supervisión de viajes',
    'super-admin' => 'Superadministración',
    'super-config' => 'Configuración efectiva',
    'super-audit' => 'Auditoría',
    'super-health' => 'Salud del servicio',
    _ => 'KIVA',
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<WorkspaceBloc, WorkspaceState>(
        builder: (context, state) {
          _tripId ??= state.tripId;
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      drawer: WorkspaceDrawer(account: widget.auth.account),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Abrir navegación',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(_title()),
        actions: [
          if (widget.section == 'notifications')
            IconButton(
              tooltip: 'Marcar todo como leído',
              onPressed: _saving ? null : _markAllRead,
              icon: const Icon(Icons.done_all),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PageBody(
        onRefresh: _load,
        children: [
          if (_tripResource) ...[
            _tripPicker(),
            if (widget.section == 'participants' && _tripId != null)
              OutlinedButton.icon(
                onPressed: () => _manageMembers(
                  _tripId!,
                  group: false,
                  canManage: _canManageSelectedTrip,
                ),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Gestionar participantes'),
              ),
            if (widget.section == 'expenses')
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _showBalances,
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Ver balances'),
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (_searchable) _searchButton(),
          if (_filterable) _filterButton(),
          if (_error != null) Notice(_error!, onRetry: _load),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _error == null) ..._content(),
        ],
      ),
      floatingActionButton: _floatingAction(),
      bottomNavigationBar: const ['groups', 'trips'].contains(widget.section)
          ? MainNavigation(section: widget.section)
          : null,
    );
  }

  bool get _searchable => const {
    'support-users',
    'admin-users',
    'admin-groups',
    'admin-trips',
    'super-audit',
  }.contains(widget.section);

  bool get _filterable => const {
    'trips',
    'support-reports',
    'support-users',
    'admin-users',
    'admin-trips',
    'super-audit',
  }.contains(widget.section);

  Widget _searchButton() => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _askSearch,
      icon: const Icon(Icons.search),
      label: Text(
        _search == null || _search!.isEmpty
            ? 'Buscar'
            : 'Búsqueda: ${_search!}',
      ),
    ),
  );

  Future<void> _askSearch() async {
    final controller = TextEditingController(text: _search ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buscar'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Texto'),
          onSubmitted: (text) => Navigator.pop(context, text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    setState(() => _search = value);
    await _load();
  }

  Widget _filterButton() => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      onPressed: _askFilters,
      icon: const Icon(Icons.filter_alt_outlined),
      label: Text(
        _filters.isEmpty ? 'Filtros' : 'Filtros (${_filters.length})',
      ),
    ),
  );

  Future<void> _askFilters() async {
    final fields = _filterFields();
    if (fields.isEmpty) return;
    final initial = <String, String>{
      for (final entry in _filters.entries)
        entry.key: entry.value?.toString() ?? '',
    };
    if (widget.section == 'support-reports') {
      initial['assignment'] = _filters['assigned_to_me'] == true
          ? 'mine'
          : _filters['unassigned'] == true
          ? 'unassigned'
          : '';
    }
    final values = await _form(
      'Filtrar ${_title().toLowerCase()}',
      fields,
      initial: initial,
    );
    if (values == null) return;
    final next = <String, Object?>{
      for (final entry in values.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };
    if (widget.section == 'support-reports') {
      final assignment = next.remove('assignment');
      if (assignment == 'mine') next['assigned_to_me'] = true;
      if (assignment == 'unassigned') next['unassigned'] = true;
    }
    if (widget.section == 'admin-trips' && _filters['group_id'] != null) {
      next['group_id'] = _filters['group_id'];
    }
    setState(() => _filters = next);
    await _load();
  }

  List<_FieldSpec> _filterFields() => switch (widget.section) {
    'trips' || 'admin-trips' => [
      const _FieldSpec(
        'status',
        'Estado',
        false,
        options: [
          _FieldOption('', 'Todos los estados'),
          _FieldOption('PLANNING', 'Planificando'),
          _FieldOption('CONFIRMED', 'Confirmado'),
          _FieldOption('COMPLETED', 'Finalizado'),
          _FieldOption('CANCELLED', 'Cancelado'),
        ],
      ),
    ],
    'support-reports' => [
      const _FieldSpec(
        'status',
        'Estado',
        false,
        options: [
          _FieldOption('', 'Todos los estados'),
          _FieldOption('OPEN', 'Abierto'),
          _FieldOption('IN_REVIEW', 'En revisión'),
          _FieldOption('ESCALATED', 'En administración'),
          _FieldOption('RESOLVED', 'Resuelto'),
          _FieldOption('CLOSED', 'Cerrado'),
        ],
      ),
      const _FieldSpec(
        'category',
        'Categoría',
        false,
        options: [
          _FieldOption('', 'Todas las categorías'),
          _FieldOption('ACCESS', 'Acceso'),
          _FieldOption('ACCOUNT', 'Cuenta'),
          _FieldOption('TRIP', 'Viaje'),
          _FieldOption('EXPENSE', 'Gastos'),
          _FieldOption('VOTING', 'Votaciones'),
          _FieldOption('RESERVATION', 'Reservas'),
          _FieldOption('TECHNICAL', 'Funcionamiento'),
          _FieldOption('OTHER', 'Otro'),
        ],
      ),
      const _FieldSpec(
        'assignment',
        'Asignación',
        false,
        options: [
          _FieldOption('', 'Cualquiera'),
          _FieldOption('mine', 'A mi cargo'),
          _FieldOption('unassigned', 'Sin asignar'),
        ],
      ),
    ],
    'support-users' || 'admin-users' => [
      const _FieldSpec(
        'role',
        'Rol',
        false,
        options: [
          _FieldOption('', 'Todos los roles'),
          _FieldOption('USER', 'Usuario'),
          _FieldOption('SUPPORT', 'Soporte'),
          _FieldOption('ADMIN', 'Administrador'),
          _FieldOption('SUPER_ADMIN', 'Superadministrador'),
        ],
      ),
      const _FieldSpec(
        'status',
        'Estado',
        false,
        options: [
          _FieldOption('', 'Todos los estados'),
          _FieldOption('ACTIVE', 'Activo'),
          _FieldOption('SUSPENDED', 'Suspendido'),
        ],
      ),
    ],
    'super-audit' => [
      _FieldSpec(
        'action',
        'Acción',
        false,
        options: [
          const _FieldOption('', 'Todas las acciones'),
          for (final entry in auditLabels.entries)
            if (!entry.key.contains('.')) _FieldOption(entry.key, entry.value),
        ],
      ),
      _FieldSpec(
        'entity',
        'Recurso',
        false,
        options: [
          const _FieldOption('', 'Todos los recursos'),
          for (final entry in auditLabels.entries)
            if (entry.key.contains('.')) _FieldOption(entry.key, entry.value),
        ],
      ),
    ],
    _ => const <_FieldSpec>[],
  };

  Widget _tripPicker() => DropdownButtonFormField<int>(
    initialValue: _tripId,
    decoration: const InputDecoration(
      labelText: 'Viaje',
      prefixIcon: Icon(Icons.flight_takeoff_outlined),
    ),
    items: [
      for (final trip in _trips)
        DropdownMenuItem<int>(
          value: _id(trip['id']),
          child: Text(_text(trip['name'])),
        ),
    ],
    onChanged: (value) async {
      setState(() => _tripId = value);
      await _load();
    },
  );

  List<Widget> _content() {
    if (_summary != null) return _summaryContent(_summary!);
    if (widget.section == 'calendar') return _calendarContent();
    if (widget.section == 'notifications') return _notificationContent();
    if (widget.section == 'reports' || widget.section == 'support-reports') {
      return _reportContent();
    }
    if (_items.isEmpty) {
      return [
        Notice(
          widget.section == 'participants' &&
                  (_search == null || _search!.trim().length < 3)
              ? 'Escribe al menos tres caracteres para buscar una cuenta.'
              : 'Aún no hay elementos para mostrar.',
        ),
      ];
    }
    return [for (final item in _items) _card(item)];
  }

  List<Widget> _summaryContent(KivaMap data) {
    return [PlatformPanel(section: widget.section, data: data)];
  }

  List<Widget> _calendarContent() {
    return [
      Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month - 1,
                      );
                    });
                    _load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatMonthYear(_calendarMonth),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month + 1,
                      );
                    });
                    _load();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      if (_items.isEmpty)
        const Notice('No hay eventos en este mes.')
      else
        for (final event in _items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(_text(event['title'])),
              subtitle: Text(
                '${_text(event['event_date'] ?? event['deadline_at'])} · ${PlatformPanel.display(event['source_type'])}',
              ),
              onTap: () => _openActionPath(_calendarActionPath(event)),
            ),
          ),
    ];
  }

  String _calendarRoute(Object? sourceType) => switch (sourceType) {
    'ACTIVITY' => 'itinerario',
    'RESERVATION' => 'reservas',
    'POLL' => 'votaciones',
    'EXPENSE' => 'gastos',
    _ => 'viajes',
  };

  String _calendarActionPath(KivaMap event) {
    final path = '/${_calendarRoute(event['source_type'])}';
    final tripId = _id(event['trip_id']) ?? _tripId;
    return tripId == null ? path : '$path?trip=$tripId';
  }

  List<Widget> _notificationContent() {
    return [
      DropdownButtonFormField<bool?>(
        initialValue: _notificationReadFilter,
        decoration: const InputDecoration(
          labelText: 'Mostrar',
          prefixIcon: Icon(Icons.filter_alt_outlined),
        ),
        hint: const Text('Todas'),
        items: const [
          DropdownMenuItem<bool?>(value: null, child: Text('Todas')),
          DropdownMenuItem<bool?>(value: false, child: Text('No leídas')),
          DropdownMenuItem<bool?>(value: true, child: Text('Leídas')),
        ],
        onChanged: (value) {
          setState(() => _notificationReadFilter = value);
          _load();
        },
      ),
      const SizedBox(height: 12),
      if (_items.isEmpty)
        const Notice('No tienes notificaciones para mostrar.')
      else
        for (final item in _items)
          Card(
            color: item['is_read'] == true
                ? null
                : Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: Icon(
                item['is_read'] == true
                    ? Icons.notifications_none
                    : Icons.notifications_active_outlined,
              ),
              title: Text(_text(item['title'])),
              subtitle: Text(_text(item['message'])),
              onTap: () => _openActionPath(item['action_path']),
              trailing: PopupMenuButton<String>(
                onSelected: (action) =>
                    _notificationAction(action, _id(item['id'])!),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'read',
                    child: Text('Marcar como leído'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
          ),
    ];
  }

  void _openActionPath(Object? rawPath) {
    final raw = rawPath?.toString().trim() ?? '';
    if (!raw.startsWith('/')) return;
    final allowed = <String>{
      '/dashboard',
      '/grupos',
      '/viajes',
      '/participantes',
      '/destinos',
      '/itinerario',
      '/gastos',
      '/votaciones',
      '/reservas',
      '/calendario',
      '/notificaciones',
      '/reportes',
      '/soporte',
    };
    final path = raw.split('?').first;
    if (!allowed.contains(path)) return;
    final query = raw.contains('?') ? raw.substring(raw.indexOf('?')) : '';
    final destination = '$path$query';
    if (!mounted) return;
    context.push(destination);
  }

  List<Widget> _reportContent() {
    if (_items.isEmpty) return const [Notice('No hay reportes para mostrar.')];
    return [
      for (final item in _items)
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(_text(item['subject'])),
            subtitle: Text(
              '${supportStatus(item['status'])} · ${supportCategories[item['category']] ?? ''}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _reportAction(action, _id(item['id'])!),
              itemBuilder: (_) => [
                if (widget.section == 'support-reports' &&
                    item['assigned_to_user_id'] == null &&
                    !const ['CLOSED', 'RESOLVED'].contains(item['status']) &&
                    (item['status'] != 'ESCALATED' ||
                        (widget.auth.account?.isAdmin ?? false)))
                  const PopupMenuItem(
                    value: 'assign',
                    child: Text('Tomar reporte'),
                  ),
                if (widget.section == 'support-reports' &&
                    item['assigned_to_user_id'] == widget.auth.account?.id &&
                    item['status'] == 'IN_REVIEW')
                  const PopupMenuItem(
                    value: 'escalate',
                    child: Text('Escalar a administración'),
                  ),
                if (widget.section == 'support-reports' &&
                    item['assigned_to_user_id'] == widget.auth.account?.id &&
                    (item['status'] == 'IN_REVIEW' ||
                        (item['status'] == 'ESCALATED' &&
                            (widget.auth.account?.isAdmin ?? false))))
                  const PopupMenuItem(
                    value: 'resolve',
                    child: Text('Resolver'),
                  ),
                if (widget.section == 'support-reports' &&
                    item['assigned_to_user_id'] == widget.auth.account?.id &&
                    item['status'] == 'RESOLVED')
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Cerrar reporte'),
                  ),
                if (widget.section == 'support-reports' &&
                    item['assigned_to_user_id'] == widget.auth.account?.id &&
                    (item['status'] == 'RESOLVED' ||
                        (item['status'] == 'ESCALATED' &&
                            (widget.auth.account?.isAdmin ?? false))))
                  const PopupMenuItem(value: 'reopen', child: Text('Reabrir')),
                if (widget.section == 'support-reports' &&
                    (widget.auth.account?.isAdmin ?? false) &&
                    !const ['CLOSED', 'RESOLVED'].contains(item['status']))
                  const PopupMenuItem(
                    value: 'reassign',
                    child: Text('Asignar a una persona'),
                  ),
                const PopupMenuItem(
                  value: 'detail',
                  child: Text('Abrir reporte'),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _card(KivaMap item) {
    if (widget.section == 'super-audit') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.history_outlined),
          title: Text(auditLabels[item['action']] ?? 'Operación registrada'),
          subtitle: Text(
            [
              item['actor_name']?.toString() ?? 'Sistema',
              if (item['actor_role'] != null)
                PlatformPanel.display(item['actor_role']),
              auditLabels[item['entity']] ?? 'Sin recurso asociado',
              if (item['created_at'] != null) _text(item['created_at']),
            ].join(' · '),
          ),
        ),
      );
    }
    final id = _id(item['id']);
    final title = _text(
      item['name'] ??
          item['full_name'] ??
          item['title'] ??
          item['question'] ??
          item['username'],
    );
    final detail = <String>[
      if (item['status'] != null) PlatformPanel.display(item['status']),
      if (item['role'] != null) PlatformPanel.display(item['role']),
      if (item['category'] != null) PlatformPanel.display(item['category']),
      if (item['group_name'] != null) 'Grupo: ${_text(item['group_name'])}',
      if (item['description'] != null) _text(item['description']),
    ].join(' · ');
    return Card(
      child: ListTile(
        isThreeLine: detail.length > 70,
        leading: CircleAvatar(
          child: Icon(
            widget.section == 'groups'
                ? Icons.groups_outlined
                : widget.section == 'trips'
                ? Icons.flight_takeoff_outlined
                : widget.section == 'participants' ||
                      widget.section == 'admin-users' ||
                      widget.section == 'support-users'
                ? Icons.person_outline
                : Icons.article_outlined,
          ),
        ),
        title: Text(title),
        subtitle: Text(detail.isEmpty ? 'Información disponible' : detail),
        trailing: id == null ? null : _actions(item, id),
        onTap: id != null && widget.section == 'support-users'
            ? () => context.push('/soporte/diagnostico?user=$id')
            : id != null && widget.section == 'admin-groups'
            ? () => context.push('/admin/viajes?group_id=$id')
            : null,
      ),
    );
  }

  Widget? _actions(KivaMap item, int id) {
    if (widget.section == 'participants') return null;
    if (widget.section == 'groups') {
      return PopupMenuButton<String>(
        onSelected: (action) => _groupAction(action, id, item),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'members',
            child: Text('Ver participantes'),
          ),
          if (item['my_role'] == 'OWNER')
            const PopupMenuItem(value: 'edit', child: Text('Editar grupo')),
          if (item['my_role'] == 'OWNER')
            const PopupMenuItem(value: 'delete', child: Text('Eliminar grupo')),
          if (item['my_role'] != null && item['my_role'] != 'OWNER')
            const PopupMenuItem(value: 'leave', child: Text('Salir del grupo')),
        ],
      );
    }
    if (widget.section == 'trips') {
      return PopupMenuButton<String>(
        onSelected: (action) => _tripAction(action, id, item),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'members',
            child: Text('Ver participantes'),
          ),
          if (item['my_role'] == 'OWNER')
            const PopupMenuItem(value: 'edit', child: Text('Editar viaje')),
          if (item['my_role'] == 'OWNER')
            const PopupMenuItem(value: 'delete', child: Text('Eliminar viaje')),
          if (item['my_role'] != null && item['my_role'] != 'OWNER')
            const PopupMenuItem(value: 'leave', child: Text('Salir del viaje')),
        ],
      );
    }
    if (_tripResource) {
      final canManage = _canManageSelectedTrip;
      final canEdit = _canEditResource(item);
      return PopupMenuButton<String>(
        onSelected: (action) => _resourceAction(action, id, item),
        itemBuilder: (_) => [
          if (widget.section == 'destinations' && canManage)
            const PopupMenuItem(
              value: 'select',
              child: Text('Cambiar selección'),
            ),
          if (widget.section == 'destinations')
            const PopupMenuItem(value: 'photo', child: Text('Cargar imagen')),
          if (widget.section == 'destinations')
            const PopupMenuItem(
              value: 'photos',
              child: Text('Gestionar imágenes'),
            ),
          if (widget.section == 'polls' && item['status'] == 'OPEN')
            const PopupMenuItem(value: 'vote', child: Text('Votar')),
          if (widget.section == 'polls' &&
              canManage &&
              item['status'] == 'OPEN')
            const PopupMenuItem(
              value: 'options',
              child: Text('Gestionar opciones'),
            ),
          if (widget.section == 'polls')
            const PopupMenuItem(
              value: 'results',
              child: Text('Ver resultados'),
            ),
          if (widget.section == 'polls' &&
              canManage &&
              item['status'] == 'OPEN')
            const PopupMenuItem(value: 'close', child: Text('Cerrar votación')),
          if (widget.section == 'reservations' && canManage)
            const PopupMenuItem(
              value: 'confirm',
              child: Text('Confirmar reserva'),
            ),
          if (canEdit)
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (canEdit)
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      );
    }
    if (widget.section == 'admin-users') {
      return PopupMenuButton<String>(
        onSelected: (action) => _adminUserAction(action, id, item),
        itemBuilder: (_) => [
          if (widget.auth.account?.role == GlobalRole.superAdmin ||
              item['role'] == 'USER') ...[
            const PopupMenuItem(value: 'active', child: Text('Activar cuenta')),
            const PopupMenuItem(
              value: 'suspended',
              child: Text('Suspender cuenta'),
            ),
          ],
          if (widget.auth.account?.role == GlobalRole.superAdmin)
            const PopupMenuItem(value: 'role', child: Text('Cambiar rol')),
        ],
      );
    }
    return null;
  }

  Widget? _floatingAction() {
    if (!const {
      'groups',
      'trips',
      'destinations',
      'activities',
      'expenses',
      'polls',
      'reservations',
      'reports',
    }.contains(widget.section)) {
      return null;
    }
    if (const {'polls', 'reservations'}.contains(widget.section) &&
        !_canManageSelectedTrip) {
      return null;
    }
    return FloatingActionButton.extended(
      onPressed: _saving ? null : _create,
      icon: const Icon(Icons.add),
      label: const Text('Nuevo'),
    );
  }

  bool get _canManageSelectedTrip {
    final selected = _trips.where((trip) => _id(trip['id']) == _tripId);
    final role = selected.isEmpty ? null : selected.first['my_role'];
    return role == 'OWNER' || role == 'ORGANIZER';
  }

  bool _canEditResource(KivaMap item) {
    if (_canManageSelectedTrip) return true;
    if (widget.section == 'destinations') {
      return _id(item['proposed_by_user_id']) == widget.auth.account?.id &&
          item['is_selected'] != true;
    }
    if (widget.section == 'expenses') {
      return _id(item['paid_by_user_id']) == widget.auth.account?.id;
    }
    return false;
  }

  Future<void> _create() async {
    if (widget.section == 'groups') return _createGroup();
    if (widget.section == 'trips') return _createTrip();
    if (_tripResource) return _createResource();
    if (widget.section == 'reports') return _createReport();
  }

  Future<void> _createGroup() async {
    final values = await _form('Nuevo grupo', const [
      _FieldSpec('name', 'Nombre', true),
      _FieldSpec('description', 'Descripción', false, maxLines: 3),
    ]);
    if (values != null) {
      await _run(
        () => widget.api.createGroup(values['name']!, values['description']),
      );
    }
  }

  Future<void> _createTrip() async {
    final groups = await widget.api.groups();
    if (groups.isEmpty) {
      return _message('Crea un grupo antes de organizar un viaje.');
    }
    final values = await _form(
      'Nuevo viaje',
      const [
        _FieldSpec('group_id', 'Grupo', true),
        _FieldSpec('name', 'Nombre', true),
        _FieldSpec('description', 'Descripción', false, maxLines: 3),
        _FieldSpec('start_date', 'Fecha inicial', false, dateOnly: true),
        _FieldSpec('end_date', 'Fecha final', false, dateOnly: true),
      ].map((field) {
        if (field.key != 'group_id') return field;
        return _FieldSpec(
          field.key,
          field.label,
          field.required,
          options: [
            for (final group in groups)
              _FieldOption(_id(group['id']).toString(), _text(group['name'])),
          ],
        );
      }).toList(),
    );
    if (values == null) return;
    final groupId = int.tryParse(values['group_id'] ?? '');
    if (groupId == null) return _message('Selecciona un grupo válido.');
    final start = values['start_date'];
    final end = values['end_date'];
    if (start != null && end != null && start.isNotEmpty && end.isNotEmpty) {
      final startDate = DateTime.tryParse(start);
      final endDate = DateTime.tryParse(end);
      if (startDate == null || endDate == null || endDate.isBefore(startDate)) {
        return _message('La fecha final debe ser posterior a la inicial.');
      }
    }
    await _run(
      () => widget.api.createTrip({
        'group_id': groupId,
        'name': values['name'],
        if ((values['description'] ?? '').isNotEmpty)
          'description': values['description'],
        if ((values['start_date'] ?? '').isNotEmpty)
          'start_date': values['start_date'],
        if ((values['end_date'] ?? '').isNotEmpty)
          'end_date': values['end_date'],
      }),
    );
  }

  List<_FieldOption> _catalogOptions(List<KivaMap> values) => [
    for (final value in values)
      if (_id(value['id']) != null)
        _FieldOption(
          _id(value['id']).toString(),
          _text(value['name'] ?? value['label'] ?? value['code']),
        ),
  ];

  Future<void> _createReservation() async {
    final types = await widget.api.catalog('reservation-types');
    if (types.isEmpty) return _message('No hay tipos de reserva disponibles.');
    final values = await _form('Nueva reserva', [
      _FieldSpec(
        'type_id',
        'Tipo de reserva',
        true,
        options: _catalogOptions(types),
      ),
      const _FieldSpec('title', 'Título', true),
      const _FieldSpec('provider', 'Proveedor', false),
      const _FieldSpec('reservation_date', 'Fecha', false, dateOnly: true),
      const _FieldSpec('amount', 'Importe', false),
    ]);
    if (values == null) return;
    final typeId = int.tryParse(values['type_id'] ?? '');
    if (typeId == null) return _message('Selecciona un tipo de reserva.');
    await _run(
      () => widget.api.createTripItem(_tripId!, widget.section, {
        'type_id': typeId,
        'title': values['title'],
        if ((values['provider'] ?? '').isNotEmpty)
          'provider': values['provider'],
        if ((values['reservation_date'] ?? '').isNotEmpty)
          'reservation_date': values['reservation_date'],
        if ((values['amount'] ?? '').isNotEmpty) 'amount': values['amount'],
      }),
    );
  }

  Future<void> _createExpense({int? editId, KivaMap? initial}) async {
    final members = await widget.api.tripMembers(_tripId!);
    final categories = await widget.api.catalog('expense-categories');
    final memberIds = <int>[];
    final names = <int, String>{};
    for (final member in members) {
      final id = _id(member['user_id']);
      if (id == null) continue;
      memberIds.add(id);
      names[id] = _text(member['full_name'] ?? member['username']);
    }
    if (memberIds.isEmpty || categories.isEmpty) {
      return _message('No hay participantes o categorías disponibles.');
    }
    if (!mounted) return;
    var payerId = _id(initial?['paid_by_user_id']) ?? widget.auth.account?.id;
    if (!memberIds.contains(payerId)) payerId = memberIds.first;
    var categoryId =
        _id(initial?['category_id']) ?? _id(categories.first['id']);
    final selected = <int>{};
    final splitControllers = <int, TextEditingController>{
      for (final id in memberIds) id: TextEditingController(),
    };
    final rawSplits = initial?['splits'];
    if (rawSplits is List) {
      for (final rawSplit in rawSplits.whereType<Map>()) {
        final id = _id(rawSplit['user_id']);
        if (id == null || !splitControllers.containsKey(id)) continue;
        selected.add(id);
        splitControllers[id]!.text = rawSplit['amount']?.toString() ?? '';
      }
    }
    if (selected.isEmpty && payerId != null) selected.add(payerId);
    final titleController = TextEditingController(
      text: initial?['title']?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: initial?['amount']?.toString() ?? '',
    );
    final dateController = TextEditingController(
      text: initial?['expense_date']?.toString() ?? _date(DateTime.now()),
    );
    final formKey = GlobalKey<FormState>();
    String? formError;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editId == null ? 'Nuevo gasto' : 'Editar gasto'),
          content: SizedBox(
            width: 500,
            height: 560,
            child: Form(
              key: formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: payerId,
                    decoration: const InputDecoration(
                      labelText: 'Quién pagó',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: [
                      for (final id in memberIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text(names[id] ?? 'Participante'),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() => payerId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona quién pagó.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final category in categories)
                        if (_id(category['id']) != null)
                          DropdownMenuItem(
                            value: _id(category['id']),
                            child: Text(
                              _text(
                                category['name'] ??
                                    category['label'] ??
                                    category['code'],
                              ),
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => categoryId = value),
                    validator: (value) =>
                        value == null ? 'Selecciona una categoría.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    maxLength: 150,
                    decoration: const InputDecoration(labelText: 'Concepto'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Completa el concepto.'
                        : null,
                  ),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Total'),
                    validator: (value) {
                      final amount = double.tryParse(
                        (value ?? '').trim().replaceAll(',', '.'),
                      );
                      return amount == null || amount <= 0
                          ? 'Escribe un importe válido.'
                          : null;
                    },
                  ),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(dateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(
                          () => dateController.text = _date(picked),
                        );
                      }
                    },
                    validator: (value) => DateTime.tryParse(value ?? '') == null
                        ? 'Selecciona una fecha.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reparto del gasto',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona las personas y asigna cuánto corresponde a cada una.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final id in memberIds)
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(id),
                            title: Text(names[id] ?? 'Participante'),
                            onChanged: (value) => setDialogState(() {
                              if (value == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: splitControllers[id],
                            enabled: selected.contains(id),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Importe',
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (formError != null)
                    Text(
                      formError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final total = double.tryParse(
                  amountController.text.trim().replaceAll(',', '.'),
                );
                final splits = <Map<String, dynamic>>[];
                var splitTotal = 0.0;
                for (final id in selected) {
                  final amount = double.tryParse(
                    splitControllers[id]!.text.trim().replaceAll(',', '.'),
                  );
                  if (amount == null || amount <= 0) {
                    setDialogState(
                      () => formError =
                          'Completa todos los importes del reparto.',
                    );
                    return;
                  }
                  splitTotal += amount;
                  splits.add({'user_id': id, 'amount': amount.toString()});
                }
                if (splits.isEmpty ||
                    total == null ||
                    (splitTotal - total).abs() > 0.01) {
                  setDialogState(
                    () => formError =
                        'El reparto debe coincidir con el total del gasto.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'paid_by_user_id': payerId,
                  'category_id': categoryId,
                  'title': titleController.text.trim(),
                  'amount': amountController.text.trim().replaceAll(',', '.'),
                  'expense_date': dateController.text,
                  'splits': splits,
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    for (final controller in splitControllers.values) {
      controller.dispose();
    }
    titleController.dispose();
    amountController.dispose();
    dateController.dispose();
    if (values == null) return;
    await _run(
      () => editId == null
          ? widget.api.createTripItem(_tripId!, widget.section, values)
          : widget.api.updateTripItem(_tripId!, widget.section, editId, values),
    );
  }

  Future<void> _createResource() async {
    if (_tripId == null) return _message('Selecciona un viaje primero.');
    if (widget.section == 'expenses') return _createExpense();
    if (widget.section == 'reservations') return _createReservation();
    final fields = switch (widget.section) {
      'destinations' => const [
        _FieldSpec('country', 'País', true),
        _FieldSpec('place_name', 'Lugar', true),
        _FieldSpec('description', 'Descripción', false, maxLines: 3),
      ],
      'activities' => const [
        _FieldSpec('title', 'Actividad', true),
        _FieldSpec('activity_date', 'Fecha', true, dateOnly: true),
        _FieldSpec('description', 'Descripción', false, maxLines: 3),
        _FieldSpec('location', 'Lugar', false),
        _FieldSpec('start_time', 'Hora', false, timeOnly: true),
        _FieldSpec('estimated_cost', 'Costo estimado', false),
      ],
      'polls' => const [
        _FieldSpec('question', 'Pregunta', true, maxLines: 3),
        _FieldSpec('options', 'Opciones separadas por coma', true, maxLines: 2),
        _FieldSpec('closes_at', 'Cierre UTC (opcional)', false),
      ],
      _ => const <_FieldSpec>[],
    };
    final values = await _form('Nuevo ${_title()}', fields);
    if (values == null) return;
    final payload = <String, dynamic>{};
    if (widget.section == 'polls') {
      payload.addAll({
        'question': values['question'],
        'options': (values['options'] ?? '')
            .split(',')
            .map((item) => {'option_text': item.trim()})
            .where((item) => (item['option_text'] ?? '').isNotEmpty)
            .toList(),
        if ((values['closes_at'] ?? '').isNotEmpty)
          'closes_at': values['closes_at'],
      });
    } else {
      for (final entry in values.entries) {
        if (entry.value.isEmpty) continue;
        payload[entry.key] = entry.key.endsWith('_id')
            ? int.tryParse(entry.value)
            : entry.value;
      }
    }
    await _run(
      () => widget.api.createTripItem(_tripId!, widget.section, payload),
    );
  }

  Future<void> _createReport() async {
    final trips = await widget.api.trips();
    final values = await _form('Nuevo reporte', [
      _FieldSpec(
        'trip_id',
        'Viaje (opcional)',
        false,
        options: _catalogOptions(trips),
      ),
      const _FieldSpec('category', 'Categoría', true),
      const _FieldSpec('subject', 'Asunto', true),
      const _FieldSpec('description', 'Descripción', true, maxLines: 5),
    ]);
    if (values == null) return;
    await _run(
      () => widget.api.createReport({
        if ((values['trip_id'] ?? '').isNotEmpty)
          'trip_id': int.tryParse(values['trip_id']!),
        'category': values['category']!.toUpperCase(),
        'subject': values['subject'],
        'description': values['description'],
      }),
    );
  }

  Future<void> _showBalances() async {
    if (_tripId == null) return;
    try {
      final results = await Future.wait([
        widget.api.expenseBalances(_tripId!),
        widget.api.tripMembers(_tripId!),
      ]);
      final balances = results[0];
      final members = results[1];
      final names = <int, String>{
        for (final member in members)
          if (_id(member['user_id']) != null)
            _id(member['user_id'])!: _text(
              member['full_name'] ?? member['username'],
            ),
      };
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Balances del viaje'),
          content: SizedBox(
            width: 460,
            height: 320,
            child: balances.isEmpty
                ? const Text('Aún no hay balances.')
                : ListView(
                    children: [
                      for (final balance in balances)
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            names[_id(balance['user_id'])] ?? 'Participante',
                          ),
                          subtitle: Text(
                            'Pagó ${_text(balance['total_paid'])} · Le corresponde ${_text(balance['total_share'])}',
                          ),
                          trailing: Text(_text(balance['balance'])),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(friendlyError(error));
    }
  }

  Future<Map<String, String>?> _form(
    String title,
    List<_FieldSpec> fields, {
    Map<String, String>? initial,
  }) async {
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field.key: TextEditingController(text: initial?[field.key] ?? ''),
    };
    final formKey = GlobalKey<FormState>();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: field.options != null
                        ? DropdownButtonFormField<String>(
                            initialValue:
                                field.options!.any(
                                  (option) =>
                                      option.value ==
                                      controllers[field.key]!.text,
                                )
                                ? controllers[field.key]!.text
                                : null,
                            decoration: InputDecoration(labelText: field.label),
                            items: [
                              for (final option in field.options!)
                                DropdownMenuItem<String>(
                                  value: option.value,
                                  child: Text(option.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                controllers[field.key]!.text = value;
                              }
                            },
                            validator: field.required
                                ? (value) => value == null || value.isEmpty
                                      ? 'Selecciona una opción.'
                                      : null
                                : null,
                          )
                        : TextFormField(
                            controller: controllers[field.key],
                            maxLines: field.maxLines,
                            maxLength: field.maxLength,
                            readOnly: field.dateOnly || field.timeOnly,
                            onTap: field.dateOnly || field.timeOnly
                                ? () async {
                                    if (field.dateOnly) {
                                      final current = DateTime.tryParse(
                                        controllers[field.key]!.text,
                                      );
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: current ?? DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        controllers[field.key]!.text = _date(
                                          picked,
                                        );
                                      }
                                    } else {
                                      final current = _parseTime(
                                        controllers[field.key]!.text,
                                      );
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: current ?? TimeOfDay.now(),
                                      );
                                      if (picked != null) {
                                        controllers[field.key]!.text =
                                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                      }
                                    }
                                  }
                                : null,
                            decoration: InputDecoration(
                              labelText: field.label,
                              suffixIcon: field.dateOnly
                                  ? const Icon(Icons.calendar_today_outlined)
                                  : field.timeOnly
                                  ? const Icon(Icons.schedule_outlined)
                                  : null,
                            ),
                            validator: field.required
                                ? (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Completa este campo.'
                                      : null
                                : null,
                          ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, <String, String>{
                for (final field in fields)
                  field.key: controllers[field.key]!.text.trim(),
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return values;
  }

  Future<void> _groupAction(String action, int id, KivaMap item) async {
    if (action == 'members') {
      return _manageMembers(
        id,
        group: true,
        canManage: item['my_role'] == 'OWNER',
      );
    }
    if (action == 'leave') {
      if (await confirmAction(
        context,
        'Salir del grupo',
        'Dejarás de ver sus viajes y participantes.',
      )) {
        final userId = widget.auth.account?.id;
        if (userId != null) {
          await _run(() => widget.api.removeGroupMember(id, userId));
        }
      }
      return;
    }
    if (action == 'delete') {
      if (await confirmAction(
        context,
        'Eliminar grupo',
        'Solo es posible cuando el grupo no tiene viajes.',
      )) {
        await _run(() => widget.api.deleteGroup(id));
      }
      return;
    }
    if (action == 'edit') {
      final values = await _form(
        'Editar grupo',
        const [
          _FieldSpec('name', 'Nombre', true),
          _FieldSpec('description', 'Descripción', false, maxLines: 3),
        ],
        initial: {
          'name': _text(item['name']),
          'description': item['description']?.toString() ?? '',
        },
      );
      if (values != null) await _run(() => widget.api.updateGroup(id, values));
    }
  }

  Future<void> _tripAction(String action, int id, KivaMap item) async {
    if (action == 'members') {
      return _manageMembers(
        id,
        group: false,
        canManage: item['my_role'] == 'OWNER' || item['my_role'] == 'ORGANIZER',
      );
    }
    if (action == 'leave') {
      if (await confirmAction(
        context,
        'Salir del viaje',
        'Dejarás de participar en este viaje.',
      )) {
        final userId = widget.auth.account?.id;
        if (userId != null) {
          await _run(() => widget.api.removeTripMember(id, userId));
        }
      }
      return;
    }
    if (action == 'delete') {
      if (await confirmAction(
        context,
        'Eliminar viaje',
        'Solo es posible cuando no tiene gastos asociados.',
      )) {
        await _run(() => widget.api.deleteTrip(id));
      }
      return;
    }
    if (action == 'edit') {
      final values = await _form(
        'Editar viaje',
        const [
          _FieldSpec('name', 'Nombre', true),
          _FieldSpec('description', 'Descripción', false, maxLines: 3),
          _FieldSpec(
            'status',
            'Estado',
            false,
            options: [
              _FieldOption('PLANNING', 'En planificación'),
              _FieldOption('CONFIRMED', 'Confirmado'),
              _FieldOption('COMPLETED', 'Finalizado'),
              _FieldOption('CANCELLED', 'Cancelado'),
            ],
          ),
          _FieldSpec('start_date', 'Fecha inicial', false, dateOnly: true),
          _FieldSpec('end_date', 'Fecha final', false, dateOnly: true),
        ],
        initial: {
          'name': _text(item['name']),
          'description': item['description']?.toString() ?? '',
          'status': _text(item['status']),
          'start_date': item['start_date']?.toString() ?? '',
          'end_date': item['end_date']?.toString() ?? '',
        },
      );
      if (values == null) return;
      await _run(
        () => widget.api.updateTrip(id, {
          for (final entry in values.entries)
            if (entry.value.isNotEmpty)
              entry.key: entry.key == 'status'
                  ? entry.value.toUpperCase()
                  : entry.value,
        }),
      );
    }
  }

  Future<void> _manageMembers(
    int ownerId, {
    required bool group,
    required bool canManage,
  }) async {
    var members = group
        ? await widget.api.groupMembers(ownerId)
        : await widget.api.tripMembers(ownerId);
    KivaMap? selectedUser;
    var selectedRole = 'MEMBER';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            group ? 'Participantes del grupo' : 'Participantes del viaje',
          ),
          content: SizedBox(
            width: 460,
            height: 420,
            child: Column(
              children: [
                if (canManage)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final user = await _chooseUser();
                            if (user != null) {
                              setDialogState(() => selectedUser = user);
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: Text(
                            selectedUser == null
                                ? 'Buscar persona'
                                : _text(
                                    selectedUser!['full_name'] ??
                                        selectedUser!['username'],
                                  ),
                          ),
                        ),
                      ),
                      if (!group)
                        DropdownButton<String>(
                          value: selectedRole,
                          items: const [
                            DropdownMenuItem(
                              value: 'MEMBER',
                              child: Text('Miembro'),
                            ),
                            DropdownMenuItem(
                              value: 'ORGANIZER',
                              child: Text('Organizador'),
                            ),
                          ],
                          onChanged: (value) => setDialogState(
                            () => selectedRole = value ?? 'MEMBER',
                          ),
                        ),
                      IconButton(
                        tooltip: 'Añadir participante',
                        icon: const Icon(Icons.person_add_outlined),
                        onPressed: () async {
                          final userId = _id(selectedUser?['id']);
                          if (userId == null) return;
                          try {
                            if (group) {
                              await widget.api.addGroupMember(ownerId, userId);
                            } else {
                              await widget.api.addTripMember(
                                ownerId,
                                userId,
                                selectedRole,
                              );
                            }
                            members = group
                                ? await widget.api.groupMembers(ownerId)
                                : await widget.api.tripMembers(ownerId);
                            setDialogState(() => selectedUser = null);
                          } catch (error) {
                            _message(friendlyError(error));
                          }
                        },
                      ),
                    ],
                  ),
                const Divider(),
                Expanded(
                  child: members.isEmpty
                      ? const Center(
                          child: Text('No hay participantes para mostrar.'),
                        )
                      : ListView(
                          children: [
                            for (final member in members)
                              ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(_text(member['full_name'])),
                                subtitle: Text(
                                  PlatformPanel.display(member['role']),
                                ),
                                trailing: canManage && member['role'] != 'OWNER'
                                    ? PopupMenuButton<String>(
                                        onSelected: (action) async {
                                          final userId = _id(member['user_id']);
                                          if (userId == null) return;
                                          try {
                                            if (action == 'remove') {
                                              if (group) {
                                                await widget.api
                                                    .removeGroupMember(
                                                      ownerId,
                                                      userId,
                                                    );
                                              } else {
                                                await widget.api
                                                    .removeTripMember(
                                                      ownerId,
                                                      userId,
                                                    );
                                              }
                                            } else if (action == 'transfer') {
                                              if (group) {
                                                await widget.api.transferGroup(
                                                  ownerId,
                                                  userId,
                                                );
                                              } else {
                                                await widget.api.transferTrip(
                                                  ownerId,
                                                  userId,
                                                );
                                              }
                                            } else if (action == 'organizer') {
                                              await widget.api.updateTripMember(
                                                ownerId,
                                                userId,
                                                'ORGANIZER',
                                              );
                                            } else if (action == 'member') {
                                              await widget.api.updateTripMember(
                                                ownerId,
                                                userId,
                                                'MEMBER',
                                              );
                                            }
                                            members = group
                                                ? await widget.api.groupMembers(
                                                    ownerId,
                                                  )
                                                : await widget.api.tripMembers(
                                                    ownerId,
                                                  );
                                            setDialogState(() {});
                                          } catch (error) {
                                            _message(friendlyError(error));
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Quitar'),
                                          ),
                                          if (member['role'] != 'OWNER' &&
                                              !group)
                                            const PopupMenuItem(
                                              value: 'organizer',
                                              child: Text('Hacer organizador'),
                                            ),
                                          if (member['role'] == 'ORGANIZER' &&
                                              !group)
                                            const PopupMenuItem(
                                              value: 'member',
                                              child: Text('Dejar como miembro'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'transfer',
                                            child: Text(
                                              'Transferir responsabilidad',
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
    await _load();
  }

  Future<KivaMap?> _chooseUser() async {
    final controller = TextEditingController();
    var loading = false;
    var results = <KivaMap>[];
    final selected = await showDialog<KivaMap>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Buscar persona'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    suffixIcon: Icon(Icons.person_search_outlined),
                  ),
                  onSubmitted: (_) async {
                    if (controller.text.trim().length < 3) return;
                    setDialogState(() => loading = true);
                    try {
                      results = await widget.api.searchUsers(
                        controller.text.trim(),
                      );
                    } finally {
                      if (dialogContext.mounted) {
                        setDialogState(() => loading = false);
                      }
                    }
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                            if (controller.text.trim().length < 3) return;
                            setDialogState(() => loading = true);
                            try {
                              results = await widget.api.searchUsers(
                                controller.text.trim(),
                              );
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => loading = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ),
                if (loading) const LinearProgressIndicator(),
                Expanded(
                  child: results.isEmpty
                      ? const Center(
                          child: Text('Busca una cuenta para añadir.'),
                        )
                      : ListView(
                          children: [
                            for (final user in results)
                              ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(
                                  _text(user['full_name'] ?? user['username']),
                                ),
                                subtitle: Text('@${_text(user['username'])}'),
                                onTap: () => Navigator.pop(dialogContext, user),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return selected;
  }

  Future<void> _resourceAction(String action, int id, KivaMap item) async {
    if (_tripId == null) return;
    if (action == 'select') {
      await _run(
        () => widget.api.selectDestination(
          _tripId!,
          id,
          item['is_selected'] != true,
        ),
      );
    } else if (action == 'photo') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (picked == null) return;
      try {
        final bytes = await picked.readAsBytes();
        await ProfileRepository.validateImage(bytes);
        await _run(
          () => widget.api.uploadDestinationPhoto(
            _tripId!,
            id,
            bytes,
            picked.name,
          ),
        );
      } catch (error) {
        _message(friendlyError(error));
      }
    } else if (action == 'photos') {
      await _photoManager(id);
    } else if (action == 'vote') {
      await _vote(id);
    } else if (action == 'options') {
      await _pollOptions(id);
    } else if (action == 'results') {
      await _pollResults(id);
    } else if (action == 'close') {
      if (await confirmAction(
        context,
        'Cerrar votación',
        'Una votación cerrada ya no recibe votos.',
      )) {
        await _run(
          () => widget.api.empty(
            'POST',
            '/trips/$_tripId/polls/$id/close',
            data: <String, dynamic>{},
          ),
        );
      }
    } else if (action == 'confirm') {
      await _run(
        () => widget.api.updateTripItem(_tripId!, widget.section, id, {
          'status': 'CONFIRMED',
        }),
      );
    } else if (action == 'edit') {
      await _editResource(id, item);
    } else if (action == 'delete') {
      if (await confirmAction(
        context,
        'Eliminar elemento',
        'Confirma que deseas eliminar este elemento.',
      )) {
        await _run(
          () => widget.api.deleteTripItem(_tripId!, widget.section, id),
        );
      }
    }
  }

  Future<void> _editResource(int id, KivaMap item) async {
    if (_tripId == null) return;
    if (widget.section == 'expenses') {
      try {
        final detail = await widget.api.tripItem(_tripId!, widget.section, id);
        if (!mounted) return;
        await _createExpense(editId: id, initial: detail);
      } catch (error) {
        _message(friendlyError(error));
      }
      return;
    }
    final fields = switch (widget.section) {
      'destinations' => const [
        _FieldSpec('country', 'País', true),
        _FieldSpec('place_name', 'Lugar', true),
        _FieldSpec('description', 'Descripción', false, maxLines: 3),
      ],
      'activities' => const [
        _FieldSpec('title', 'Actividad', true),
        _FieldSpec('activity_date', 'Fecha', true, dateOnly: true),
        _FieldSpec('description', 'Descripción', false, maxLines: 3),
        _FieldSpec('location', 'Lugar', false),
        _FieldSpec('start_time', 'Hora de inicio', false, timeOnly: true),
        _FieldSpec('estimated_cost', 'Costo estimado', false),
        _FieldSpec(
          'status',
          'Estado',
          false,
          options: [
            _FieldOption('PROPOSED', 'Propuesta'),
            _FieldOption('APPROVED', 'Aprobada'),
            _FieldOption('CANCELLED', 'Cancelada'),
          ],
        ),
      ],
      'polls' => const [
        _FieldSpec('question', 'Pregunta', true, maxLines: 3),
        _FieldSpec('closes_at', 'Cierre UTC (opcional)', false),
      ],
      'reservations' => const [
        _FieldSpec('title', 'Título', true),
        _FieldSpec('provider', 'Proveedor', false),
        _FieldSpec('reservation_date', 'Fecha', false, dateOnly: true),
        _FieldSpec('amount', 'Importe', false),
        _FieldSpec(
          'status',
          'Estado',
          false,
          options: [
            _FieldOption('PENDING', 'Pendiente'),
            _FieldOption('CONFIRMED', 'Confirmada'),
            _FieldOption('CANCELLED', 'Cancelada'),
          ],
        ),
      ],
      _ => const <_FieldSpec>[],
    };
    final initial = <String, String>{
      for (final field in fields) field.key: item[field.key]?.toString() ?? '',
    };
    final values = await _form('Editar ${_title()}', fields, initial: initial);
    if (values == null) return;
    await _run(
      () => widget.api
          .updateTripItem(_tripId!, widget.section, id, <String, dynamic>{
            for (final entry in values.entries)
              if (entry.value.isNotEmpty)
                entry.key: entry.key == 'status'
                    ? entry.value.toUpperCase()
                    : entry.value,
          }),
    );
  }

  Future<void> _photoManager(int destinationId) async {
    if (_tripId == null) return;
    try {
      var photos = await widget.api.destinationPhotos(_tripId!, destinationId);
      final destination = _items.cast<KivaMap?>().firstWhere(
        (item) => _id(item?['id']) == destinationId,
        orElse: () => null,
      );
      final canReorder =
          _canManageSelectedTrip ||
          _id(destination?['proposed_by_user_id']) == widget.auth.account?.id;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Imágenes del destino'),
            content: SizedBox(
              width: 460,
              height: 360,
              child: photos.isEmpty
                  ? const Center(child: Text('Aún no hay imágenes.'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: photos.length,
                      onReorderItem: (oldIndex, newIndex) async {
                        if (!canReorder) return;
                        final previous = List<KivaMap>.from(photos);
                        final reordered = List<KivaMap>.from(photos);
                        final moved = reordered.removeAt(oldIndex);
                        reordered.insert(newIndex, moved);
                        setDialogState(() => photos = reordered);
                        try {
                          final saved = await widget.api
                              .reorderDestinationPhotos(
                                _tripId!,
                                destinationId,
                                [
                                  for (final item in reordered)
                                    _id(item['id'])!,
                                ],
                              );
                          if (dialogContext.mounted && saved.isNotEmpty) {
                            setDialogState(() => photos = saved);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() => photos = previous);
                          }
                          _message(friendlyError(error));
                        }
                      },
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        final photoId = _id(photo['id']);
                        return ListTile(
                          key: ValueKey(photoId ?? index),
                          leading: photoId == null
                              ? const Icon(Icons.image_outlined)
                              : _DestinationPhotoThumbnail(
                                  api: widget.api,
                                  tripId: _tripId!,
                                  destinationId: destinationId,
                                  photoId: photoId,
                                  onTap: () =>
                                      _showPhotoPreview(destinationId, photoId),
                                ),
                          title: Text('Imagen ${_text(photo['position'])}'),
                          subtitle: Text(_text(photo['created_at'])),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: canReorder
                                    ? const Icon(Icons.drag_handle)
                                    : const SizedBox.shrink(),
                              ),
                              if (_id(photo['uploaded_by_user_id']) ==
                                      widget.auth.account?.id ||
                                  _canManageSelectedTrip)
                                IconButton(
                                  tooltip: 'Eliminar imagen',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: photoId == null
                                      ? null
                                      : () async {
                                          try {
                                            await widget.api
                                                .deleteDestinationPhoto(
                                                  _tripId!,
                                                  destinationId,
                                                  photoId,
                                                );
                                            photos = await widget.api
                                                .destinationPhotos(
                                                  _tripId!,
                                                  destinationId,
                                                );
                                            setDialogState(() {});
                                          } catch (error) {
                                            _message(friendlyError(error));
                                          }
                                        },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
      await _load();
    } catch (error) {
      _message(friendlyError(error));
    }
  }

  Future<void> _showPhotoPreview(int destinationId, int photoId) async {
    if (_tripId == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<Uint8List>(
            future: widget.api.destinationPhotoBytes(
              _tripId!,
              destinationId,
              photoId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  width: 280,
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 280,
                  height: 220,
                  child: Center(child: Text('No se pudo cargar la imagen.')),
                );
              }
              return InteractiveViewer(
                child: Image.memory(
                  snapshot.data!,
                  width: 420,
                  height: 420,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 280,
                    height: 220,
                    child: Center(child: Text('No se pudo cargar la imagen.')),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _vote(int pollId) async {
    if (_tripId == null) return;
    try {
      final detail = await widget.api.tripItem(_tripId!, 'polls', pollId);
      final results = await widget.api.pollResults(_tripId!, pollId);
      final options = detail['options'] is List
          ? (detail['options'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <KivaMap>[];
      final selected = <int>{};
      if (results['options'] is List) {
        for (final option in (results['options'] as List).whereType<Map>()) {
          if (option['selected_by_me'] == true) {
            final optionId = _id(option['id']);
            if (optionId != null) selected.add(optionId);
          }
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(_text(detail['question'])),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  CheckboxListTile(
                    value: selected.contains(_id(option['id'])),
                    title: Text(_text(option['option_text'])),
                    onChanged: (checked) => setDialogState(() {
                      final optionId = _id(option['id']);
                      if (optionId == null) return;
                      if (checked == true) {
                        selected.add(optionId);
                      } else {
                        selected.remove(optionId);
                      }
                    }),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  await widget.api.empty(
                    'PUT',
                    '/trips/$_tripId/polls/$pollId/votes',
                    data: {'option_ids': selected.toList()},
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Guardar voto'),
              ),
            ],
          ),
        ),
      );
      await _load();
    } catch (error) {
      _message(friendlyError(error));
    }
  }

  Future<void> _pollOptions(int pollId) async {
    if (_tripId == null) return;
    try {
      final detail = await widget.api.tripItem(_tripId!, 'polls', pollId);
      var options = detail['options'] is List
          ? (detail['options'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <KivaMap>[];
      final addController = TextEditingController();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Opciones de la votación'),
            content: SizedBox(
              width: 460,
              height: 380,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addController,
                          maxLength: 200,
                          decoration: const InputDecoration(
                            labelText: 'Nueva opción',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Añadir opción',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          if (addController.text.trim().isEmpty) return;
                          try {
                            await widget.api.addPollOption(
                              _tripId!,
                              pollId,
                              addController.text.trim(),
                            );
                            final fresh = await widget.api.tripItem(
                              _tripId!,
                              'polls',
                              pollId,
                            );
                            options = (fresh['options'] as List)
                                .whereType<Map>()
                                .map((item) => Map<String, dynamic>.from(item))
                                .toList();
                            addController.clear();
                            setDialogState(() {});
                          } catch (error) {
                            _message(friendlyError(error));
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final option in options)
                          ListTile(
                            title: Text(_text(option['option_text'])),
                            subtitle: Text(
                              'Opción ${_text(option['option_number'])}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                final optionId = _id(option['id']);
                                if (optionId == null) return;
                                try {
                                  if (action == 'delete') {
                                    await widget.api.deletePollOption(
                                      _tripId!,
                                      pollId,
                                      optionId,
                                    );
                                  } else {
                                    final value = await _form(
                                      'Editar opción',
                                      const [
                                        _FieldSpec(
                                          'option_text',
                                          'Texto',
                                          true,
                                        ),
                                      ],
                                      initial: {
                                        'option_text': _text(
                                          option['option_text'],
                                        ),
                                      },
                                    );
                                    if (value != null) {
                                      await widget.api.updatePollOption(
                                        _tripId!,
                                        pollId,
                                        optionId,
                                        value,
                                      );
                                    }
                                  }
                                  final fresh = await widget.api.tripItem(
                                    _tripId!,
                                    'polls',
                                    pollId,
                                  );
                                  options = (fresh['options'] as List)
                                      .whereType<Map>()
                                      .map(
                                        (item) =>
                                            Map<String, dynamic>.from(item),
                                      )
                                      .toList();
                                  setDialogState(() {});
                                } catch (error) {
                                  _message(friendlyError(error));
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
      addController.dispose();
      await _load();
    } catch (error) {
      _message(friendlyError(error));
    }
  }

  Future<void> _pollResults(int pollId) async {
    if (_tripId == null) return;
    try {
      final results = await widget.api.pollResults(_tripId!, pollId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resultados'),
          content: SizedBox(
            width: 420,
            height: 300,
            child: (results['options'] is List)
                ? ListView(
                    children: [
                      Text('Votantes: ${_text(results['total_voters'])}'),
                      for (final option
                          in (results['options'] as List).whereType<Map>())
                        ListTile(
                          title: Text(_text(option['option_text'])),
                          trailing: Text(_text(option['votes_count'])),
                        ),
                    ],
                  )
                : const Text('No hay resultados disponibles.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      _message(friendlyError(error));
    }
  }

  Future<void> _notificationAction(String action, int id) async {
    if (action == 'read') {
      await _run(() => widget.api.markNotificationRead(id, true));
    } else {
      await _run(() => widget.api.deleteNotification(id));
    }
  }

  Future<void> _markAllRead() => _run(widget.api.markAllNotificationsRead);

  Future<void> _reportAction(String action, int id) async {
    if (_saving) return;
    if (action == 'reassign') {
      try {
        final report = await widget.api.supportReport(id);
        final agents = await widget.api.supportAgents();
        if (!mounted) return;
        final selected = await showDialog<int>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Asignar reporte'),
            children: [
              for (final agent in agents)
                if (report['status'] != 'ESCALATED' ||
                    const ['ADMIN', 'SUPER_ADMIN'].contains(agent['role']))
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, agent['id'] as int),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(agent['full_name'].toString()),
                    ),
                  ),
            ],
          ),
        );
        if (selected != null && mounted) {
          await _run(() => widget.api.assignSupport(id, selected));
        }
      } catch (error) {
        _message(friendlyError(error));
      }
      return;
    }
    if (action == 'assign') {
      await _run(() => widget.api.assignSupportSelf(id));
      return;
    }
    if (action == 'escalate') {
      final values = await _form('Escalar reporte', const [
        _FieldSpec('reason', 'Motivo', true, maxLines: 4, maxLength: 900),
      ]);
      if (values != null) {
        await _run(() => widget.api.escalateSupport(id, values['reason']!));
      }
      return;
    }
    if (action == 'resolve') {
      final values = await _form('Resolver reporte', const [
        _FieldSpec(
          'response',
          'Respuesta para la persona',
          true,
          maxLines: 5,
          maxLength: 1000,
        ),
      ]);
      if (values != null) {
        await _run(
          () => widget.api.updateSupportReport(id, {
            'status': 'RESOLVED',
            'response': values['response'],
          }),
        );
      }
      return;
    }
    if (action == 'close' || action == 'reopen') {
      await _run(
        () => widget.api.updateSupportReport(id, {
          'status': action == 'close' ? 'CLOSED' : 'IN_REVIEW',
        }),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SupportConversation(
          repository: SupportRepository(widget.api.client),
          reportId: id,
          staff: widget.section == 'support-reports',
          staffId: widget.auth.account?.id,
          admin: widget.auth.account?.isAdmin ?? false,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _adminUserAction(String action, int id, KivaMap item) async {
    if (action == 'active' || action == 'suspended') {
      await _run(
        () => widget.api.updateAdminUser(id, {
          'status': action == 'active' ? 'ACTIVE' : 'SUSPENDED',
        }),
      );
      return;
    }
    final values = await _form(
      'Cambiar rol',
      const [
        _FieldSpec(
          'role',
          'Rol',
          true,
          options: [
            _FieldOption('USER', 'Usuario'),
            _FieldOption('SUPPORT', 'Soporte'),
            _FieldOption('ADMIN', 'Administrador'),
            _FieldOption('SUPER_ADMIN', 'Superadministrador'),
          ],
        ),
      ],
      initial: {'role': _text(item['role'])},
    );
    if (values != null) {
      await _run(
        () => widget.api.updateAdminUser(id, {
          'role': values['role']!.toUpperCase(),
        }),
      );
    }
  }

  Future<void> _run(Future<dynamic> Function() operation) => _bloc.dispatch(
    WorkspaceActionRequested(
      operation: operation,
      search: _search,
      tripId: _tripId,
      calendarMonth: _calendarMonth,
      notificationRead: _notificationReadFilter,
      filters: _filters,
    ),
  );

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label,
    this.required, {
    this.maxLines = 1,
    this.maxLength,
    this.options,
    this.dateOnly = false,
    this.timeOnly = false,
  });
  final String key;
  final String label;
  final bool required;
  final int maxLines;
  final int? maxLength;
  final List<_FieldOption>? options;
  final bool dateOnly;
  final bool timeOnly;
}

class _FieldOption {
  const _FieldOption(this.value, this.label);

  final String value;
  final String label;
}

class _DestinationPhotoThumbnail extends StatelessWidget {
  const _DestinationPhotoThumbnail({
    required this.api,
    required this.tripId,
    required this.destinationId,
    required this.photoId,
    required this.onTap,
  });

  final KivaApi api;
  final int tripId;
  final int destinationId;
  final int photoId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: api.destinationPhotoBytes(tripId, destinationId, photoId),
    builder: (context, snapshot) {
      final child = snapshot.hasData
          ? Image.memory(
              snapshot.data!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
            )
          : const SizedBox(
              width: 52,
              height: 52,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
      return InkWell(
        onTap: snapshot.hasData ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
      );
    },
  );
}
