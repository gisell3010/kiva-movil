sealed class WorkspaceEvent {
  const WorkspaceEvent();
}

final class WorkspaceLoadRequested extends WorkspaceEvent {
  const WorkspaceLoadRequested({
    this.search,
    this.tripId,
    this.calendarMonth,
    this.notificationRead,
    this.filters,
  });

  final String? search;
  final int? tripId;
  final DateTime? calendarMonth;
  final bool? notificationRead;
  final Map<String, Object?>? filters;
}

final class WorkspaceActionRequested extends WorkspaceEvent {
  const WorkspaceActionRequested({
    required this.operation,
    this.search,
    this.tripId,
    this.calendarMonth,
    this.notificationRead,
    this.filters,
  });

  final Future<dynamic> Function() operation;
  final String? search;
  final int? tripId;
  final DateTime? calendarMonth;
  final bool? notificationRead;
  final Map<String, Object?>? filters;
}
