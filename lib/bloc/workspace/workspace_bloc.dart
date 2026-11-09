import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'workspace_event.dart';
import 'workspace_state.dart';
export 'workspace_event.dart';
export 'workspace_state.dart';

import 'package:kiva_mobile_final/repositories/workspace/kiva_api.dart';

/// BLoC de lectura y mutación de los módulos protegidos de la aplicación.
///
/// Mantiene fuera de la vista la transición de estados de red y conserva una
/// única fuente de verdad para listas, paneles, selección de viaje y errores.
class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  WorkspaceBloc(this.api, {required this.section})
    : super(const WorkspaceState()) {
    on<WorkspaceEvent>((event, emit) async {
      _emitter = emit;
      try {
        if (event is WorkspaceLoadRequested) {
          await _load(event);
        } else if (event is WorkspaceActionRequested) {
          await _run(event);
        }
      } finally {
        _emitter = null;
        _pending.remove(event)?.complete();
      }
    }, transformer: (events, mapper) => events.asyncExpand(mapper));
  }
  final _pending = Map<WorkspaceEvent, Completer<void>>.identity();
  Emitter<WorkspaceState>? _emitter;

  final KivaApi api;
  String section;
  WorkspaceState get _state => state;

  Future<void> dispatch(WorkspaceEvent event) {
    if (isClosed) return Future.value();
    final completion = Completer<void>();
    _pending[event] = completion;
    add(event);
    return completion.future;
  }

  Future<void> _load(WorkspaceLoadRequested event) async {
    _emit(
      WorkspaceState(
        status: WorkspaceStatus.loading,
        items: _state.items,
        trips: _state.trips,
        tripId: event.tripId ?? _state.tripId,
      ),
    );
    try {
      final result = await _fetch(event);
      _emit(
        WorkspaceState(
          status: WorkspaceStatus.ready,
          items: result.items,
          trips: result.trips,
          summary: result.summary,
          tripId: result.tripId,
        ),
      );
    } catch (error) {
      _emit(
        WorkspaceState(
          status: WorkspaceStatus.failure,
          items: _state.items,
          trips: _state.trips,
          summary: _state.summary,
          tripId: event.tripId ?? _state.tripId,
          error: error,
        ),
      );
    }
  }

  Future<void> _run(WorkspaceActionRequested event) async {
    _emit(
      WorkspaceState(
        status: WorkspaceStatus.saving,
        items: _state.items,
        trips: _state.trips,
        summary: _state.summary,
        tripId: event.tripId ?? _state.tripId,
      ),
    );
    try {
      await event.operation();
      final result = await _fetch(
        WorkspaceLoadRequested(
          search: event.search,
          tripId: event.tripId ?? _state.tripId,
          calendarMonth: event.calendarMonth,
          notificationRead: event.notificationRead,
          filters: event.filters,
        ),
      );
      _emit(
        WorkspaceState(
          status: WorkspaceStatus.ready,
          items: result.items,
          trips: result.trips,
          summary: result.summary,
          tripId: result.tripId,
        ),
      );
    } catch (error) {
      _emit(
        WorkspaceState(
          status: WorkspaceStatus.failure,
          items: _state.items,
          trips: _state.trips,
          summary: _state.summary,
          tripId: event.tripId ?? _state.tripId,
          error: error,
        ),
      );
    }
  }

  Future<_WorkspaceResult> _fetch(WorkspaceLoadRequested event) async {
    final search = event.search;
    var items = <KivaMap>[];
    var trips = <KivaMap>[];
    KivaMap? summary;
    var tripId = event.tripId;
    final activeFilters = event.filters ?? const <String, Object?>{};
    final queryFilters = _withSearch(activeFilters, search);

    switch (section) {
      case 'groups':
        items = await api.groups(search: search);
      case 'trips':
        items = await api.trips(
          groupId: _id(activeFilters['group_id']),
          status: _nonEmpty(activeFilters['status']),
        );
      case 'participants':
        trips = await api.trips();
        tripId ??= trips.isEmpty ? null : _id(trips.first['id']);
        items = tripId == null ? <KivaMap>[] : await api.tripMembers(tripId);
      case 'calendar':
        final month = event.calendarMonth ?? DateTime.now();
        final start = DateTime(month.year, month.month, 1);
        final end = DateTime(month.year, month.month + 1, 0);
        items = await api.calendar(
          startDate: _date(start),
          endDate: _date(end),
          tripId: event.tripId,
        );
      case 'notifications':
        items = await api.notifications(isRead: event.notificationRead);
      case 'reports':
        items = await api.myReports();
      case 'support':
        summary = await api.supportDashboard();
        final recent = await api.page(
          '/support/reports',
          filters: const {'page_size': 5},
        );
        summary = {...summary, 'recent_reports': recent['items']};
      case 'support-reports':
        items = await api.supportReports(filters: queryFilters);
      case 'support-users':
        items =
            (search == null || search.trim().isEmpty) && activeFilters.isEmpty
            ? <KivaMap>[]
            : await api.supportUsers(filters: queryFilters);
      case 'admin':
        summary = await api.adminDashboard();
        final users = await api.page(
          '/admin/users',
          filters: const {'page_size': 5},
        );
        final groups = await api.page(
          '/admin/groups',
          filters: const {'page_size': 5},
        );
        summary = {
          ...summary,
          'recent_users': users['items'],
          'recent_groups': groups['items'],
        };
      case 'admin-users':
        items = await api.adminUsers(filters: queryFilters);
      case 'admin-groups':
        items = await api.adminGroups(search: search);
      case 'admin-trips':
        items = await api.adminTrips(filters: queryFilters);
      case 'super-admin':
        summary = await api.superAdminDashboard();
      case 'super-config':
        summary = await api.systemConfig();
      case 'super-audit':
        items = await api.auditLogs(filters: queryFilters);
      case 'super-health':
        summary = await api.systemHealth();
      default:
        if (_isTripResource) {
          trips = await api.trips();
          tripId ??= trips.isEmpty ? null : _id(trips.first['id']);
          items = tripId == null
              ? <KivaMap>[]
              : await api.tripCollection(tripId, section);
        }
    }
    return _WorkspaceResult(
      items: items,
      trips: trips,
      summary: summary,
      tripId: tripId,
    );
  }

  bool get _isTripResource => const {
    'destinations',
    'activities',
    'expenses',
    'polls',
    'reservations',
  }.contains(section);

  int? _id(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Map<String, Object?> _withSearch(
    Map<String, Object?> filters,
    String? search,
  ) => <String, Object?>{
    ...filters,
    if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
  };

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);

  void _emit(WorkspaceState next) {
    if (!isClosed && _emitter?.isDone == false) _emitter!(next);
  }
}

class _WorkspaceResult {
  const _WorkspaceResult({
    required this.items,
    required this.trips,
    required this.summary,
    required this.tripId,
  });

  final List<KivaMap> items;
  final List<KivaMap> trips;
  final KivaMap? summary;
  final int? tripId;
}
